#!/usr/bin/env python3
"""Static checks for the D3D11 shader port.

This is intentionally dependency-free. It does not replace compilation with
fxc/dxc; use --fxc to additionally compile every target when a compiler is
available.
"""
from __future__ import annotations

import argparse
import json
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
REPO = ROOT.parent


def strip_comments(text: str) -> str:
    out = []
    i = 0
    n = len(text)
    quote = None
    while i < n:
        if quote:
            out.append(text[i])
            if text[i] == "\\" and i + 1 < n:
                i += 1
                out.append(text[i])
            elif text[i] == quote:
                quote = None
            i += 1
            continue
        if text[i] in "\"'":
            quote = text[i]
            out.append(text[i])
            i += 1
        elif text.startswith("//", i):
            j = text.find("\n", i)
            j = n if j < 0 else j
            out.append(" " * (j - i))
            i = j
        elif text.startswith("/*", i):
            j = text.find("*/", i + 2)
            j = n if j < 0 else j + 2
            out.append("".join(c if c == "\n" else " " for c in text[i:j]))
            i = j
        else:
            out.append(text[i])
            i += 1
    return "".join(out)


def fail(errors: list[str], path: Path, msg: str) -> None:
    errors.append(f"{path.relative_to(ROOT)}: {msg}")


def check_file(path: Path, errors: list[str]) -> None:
    text = path.read_text(encoding="utf-8")
    code = strip_comments(text)
    rel = path.relative_to(ROOT).as_posix()

    # The SMAA library intentionally retains upstream HLSL3/GLSL backends.
    if rel != "SMAA/SMAA.hlsl":
        for pattern, msg in [
            (r"\bsampler(?:1D|2D|3D|CUBE)\b", "legacy sampler object"),
            (r"\btex(?:1D|2D|3D|CUBE)(?:proj|lod|bias|grad)?\s*\(", "legacy texture intrinsic"),
            (r"\bTEXUNIT\d+\b", "legacy Cg TEXUNIT semantic"),
            (r"\buniform\b", "legacy uniform; expected cbuffer/global resource"),
            (r":\s*_GL_\w+", "legacy Cg state annotation"),
        ]:
            if re.search(pattern, code):
                fail(errors, path, msg)

    # Texture/sampler register pairing.
    textures = dict(re.findall(r"\bTexture(?:2D|Cube)\s+(\w+)\s*:\s*register\(t(\d+)\)", code))
    samplers = dict(re.findall(r"\bSamplerState\s+(\w+)\s*:\s*register\(s(\d+)\)", code))
    shared_smaa = rel == "SMAA/SMAA_Passes.hlsl"
    for name, slot in textures.items():
        if shared_smaa:
            continue
        expected = name + "_Sampler"
        if expected not in samplers:
            fail(errors, path, f"missing sampler {expected} for {name}")
        elif samplers[expected] != slot:
            fail(errors, path, f"sampler slot mismatch for {name}")
    if re.search(r"\bTexture(?:2D|Cube)\s+\w+\s*:\s*register\(s\d+\)", code):
        fail(errors, path, "texture bound to sampler register")

    # Constant-buffer registers must be unique within a translation unit.
    cb_slots = re.findall(r"\bcbuffer\s+\w+\s*:\s*register\(b(\d+)\)", code)
    if len(cb_slots) != len(set(cb_slots)):
        fail(errors, path, "duplicate cbuffer register slot")
    if any(int(slot) > 13 for slot in cb_slots):
        fail(errors, path, "cbuffer slot exceeds D3D11 stage limit")

    # Brace balance outside comments/strings.
    depth = 0
    for ch in code:
        if ch == "{":
            depth += 1
        elif ch == "}":
            depth -= 1
            if depth < 0:
                fail(errors, path, "unbalanced closing brace")
                break
    if depth != 0:
        fail(errors, path, "unbalanced braces")

    # Entry-point semantics.
    if path.name != "SMAA.hlsl" and path.suffix == ".hlsl":
        is_vs = re.search(r"(VS|VP)\d*(?:_[^.]*)?\.hlsl$", path.name) or path.name in {
            "FogTest.hlsl",
            "WaterTexCoord.hlsl",
        }
        if is_vs:
            if "SV_Position" not in code:
                fail(errors, path, "vertex shader output missing SV_Position")
            if re.search(r"struct\s+\w*(?:In|Input|appdata|vertex_in)\w*\s*\{[^}]*:\s*SV_Position", code, re.I | re.S):
                fail(errors, path, "vertex input uses SV_Position")
        elif "main" in code and rel != "SMAA/SMAA_Passes.hlsl":
            if not re.search(r"\bmain\s*\([^)]*\)\s*:\s*SV_Target\d*", code, re.S):
                fail(errors, path, "pixel shader main missing SV_Target semantic")

    if rel.startswith("SpeedTree/") and path.suffix == ".hlsl":
        if "SpeedTreeDefaults.hlsli" not in text:
            fail(errors, path, "missing SpeedTreeDefaults.hlsli include")


def compile_targets(fxc: Path, output_dir: Path, errors: list[str]) -> None:
    manifest = json.loads((ROOT / "Shaders.json").read_text(encoding="utf-8"))
    for target in manifest["targets"]:
        source = REPO / target["source"]
        profile = "vs_5_0" if target["stage"] == "vs" else "ps_5_0"
        out = output_dir / Path(target["output"]).name
        out.parent.mkdir(parents=True, exist_ok=True)
        cmd = [
            str(fxc), "/nologo", "/T", profile, "/E", target["entry"],
            "/Zpc", "/Fo", str(out), str(source),
        ]
        result = subprocess.run(cmd, capture_output=True, text=True)
        if result.returncode != 0:
            errors.append(f"compile {target['source']} ({target['entry']}): {result.stderr or result.stdout}")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--fxc", type=Path, help="optional path to fxc.exe for real compilation")
    parser.add_argument("--output-dir", type=Path, default=ROOT / "Compiled")
    args = parser.parse_args()

    errors: list[str] = []
    originals = sorted((REPO / "HLSL").rglob("*.hlsl"))
    for original in originals:
        rel = original.relative_to(REPO / "HLSL")
        if not (ROOT / rel).exists():
            errors.append(f"missing port for HLSL/{rel}")
    if not (ROOT / "SMAA/SMAA.hlsl").exists():
        errors.append("missing port for SMAA/SMAA.hlsl")

    for path in sorted(ROOT.rglob("*.hlsl")):
        check_file(path, errors)
    for path in sorted(ROOT.rglob("*.hlsli")):
        check_file(path, errors)

    manifest = json.loads((ROOT / "Shaders.json").read_text(encoding="utf-8"))
    for target in manifest["targets"]:
        if not (REPO / target["source"]).exists():
            errors.append(f"manifest target source missing: {target['source']}")

    if args.fxc:
        compile_targets(args.fxc, args.output_dir, errors)

    if errors:
        print(f"FAILED: {len(errors)} issue(s)", file=sys.stderr)
        for error in errors:
            print(" -", error, file=sys.stderr)
        return 1
    count = len(list(ROOT.rglob("*.hlsl"))) + len(list(ROOT.rglob("*.hlsli")))
    print(f"OK: {count} HLSL/HLSLI files passed static checks")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

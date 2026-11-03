#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Оффлайн-компиляция HLSL_D3D11 через fxc.exe без запуска игры.

Скрипт проверяет исходники HLSL_D3D11 и не подменяет рендерер: он не проверяет
связывание VS/PS, раскладку constant buffer'ов, привязку SRV/sampler'ов и
поведение на GPU.

По умолчанию используется Shaders.json из каталога порта. Если рядом лежит
EngineDefines.json, скрипт дополнительно разворачивает варианты дефайнов, с
которыми движок реально грузит шейдеры. Один набор дефайнов — отдельная сборка;
наборы не склеиваются. Профили по умолчанию — vs_4_0 / ps_4_0. Для SM5 можно
передать --shader-model 5.

Файлы, которых нет в манифесте как отдельные цели компиляции, выводятся в отчёт
как пропущенные библиотеки/заголовки. Например SMAA/SMAA.hlsl не собирается с
/E main, а SMAA/SMAA_Passes.hlsl собирается по каждой своей точке входа.

Использование:
    python tools/compile_shaders.py HLSL_D3D11
    python tools/compile_shaders.py HLSL_D3D11 --only MegaPlanePS
    python tools/compile_shaders.py HLSL_D3D11 --shader-model 5
    python tools/compile_shaders.py HLSL_D3D11 --define USE_FOG,USE_SHADOWS
    python tools/compile_shaders.py HLSL_D3D11 --list
    python tools/compile_shaders.py HLSL_D3D11 --no-engine-defines
    python tools/compile_shaders.py HLSL_D3D11 --fxc "C:\\Program Files (x86)\\Windows Kits\\10\\bin\\10.0.22621.0\\x64\\fxc.exe"

Код возврата:
    0 — все выбранные сборки собрались;
    1 — есть ошибки компиляции;
    2 — не найден fxc, каталог, манифест, выбранные цели или есть дрейф таблицы.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import locale
import os
import re
import shutil
import subprocess
import sys
import tempfile
from collections import OrderedDict
from dataclasses import dataclass
from pathlib import Path
from typing import Iterable

DEFAULT_SHADER_MODEL = 4
SUPPORTED_PROFILES = {"vs_4_0", "ps_4_0", "vs_5_0", "ps_5_0"}
DEFINE_RE = re.compile(r"^[A-Za-z_]\w*(?:=.*)?$")


@dataclass(frozen=True)
class Target:
    source: Path
    rel_source: str
    stage: str
    entry: str
    defines: tuple[str, ...] = ()

    def profile(self, shader_model: int, override: str = "") -> str:
        if override:
            return override
        return f"{self.stage}_{shader_model}_0"

    @property
    def variant_key(self) -> tuple[str, tuple[str, ...]]:
        return (self.rel_source, self.defines)


def version_key(name: str) -> tuple[int, ...]:
    return tuple(int(x) for x in re.findall(r"\d+", name))


def find_fxc(explicit: str = "") -> str | None:
    """Явный путь, PATH, затем Windows SDK 10/8.1. Предпочитается x64."""
    if explicit:
        p = Path(explicit).expanduser()
        return str(p) if p.is_file() else None

    for name in ("fxc.exe", "fxc"):
        found = shutil.which(name)
        if found:
            return found

    roots: list[Path] = []
    for env in ("ProgramFiles(x86)", "ProgramFiles"):
        base = os.environ.get(env)
        if base:
            roots.append(Path(base) / "Windows Kits" / "10" / "bin")
            roots.append(Path(base) / "Windows Kits" / "8.1" / "bin")

    candidates: list[Path] = []
    for root in roots:
        if not root.is_dir():
            continue
        for version in sorted(root.iterdir(), key=lambda p: version_key(p.name), reverse=True):
            for arch in ("x64", "x86"):
                candidate = version / arch / "fxc.exe"
                if candidate.is_file():
                    candidates.append(candidate)
        direct = root / "fxc.exe"
        if direct.is_file():
            candidates.append(direct)

    return str(candidates[0]) if candidates else None


def find_manifest(shader_dir: Path) -> Path | None:
    current = shader_dir
    for _ in range(5):
        candidate = current / "Shaders.json"
        if candidate.is_file():
            return candidate
        if current.parent == current:
            break
        current = current.parent
    return None


def is_under(path: Path, directory: Path) -> bool:
    try:
        return os.path.commonpath([str(path), str(directory)]) == str(directory)
    except ValueError:
        return False


def resolve_source(raw_source: str, repo_root: Path, port_root: Path) -> Path | None:
    raw = Path(raw_source)
    candidates = [repo_root / raw, port_root / raw]
    if len(raw.parts) > 1:
        candidates.append(port_root / Path(*raw.parts[1:]))
    for candidate in candidates:
        if candidate.is_file():
            return candidate.resolve()
    return None


def normalize_defines(values: Iterable[str]) -> list[str]:
    result: list[str] = []
    for value in values:
        for part in str(value).split(","):
            part = part.strip()
            if not part:
                continue
            if not DEFINE_RE.match(part):
                raise ValueError(f"некорректный define: {part!r}")
            if part not in result:
                result.append(part)
    return result


def defines_label(defines: Iterable[str]) -> str:
    items = list(defines)
    return " ".join(items) if items else "-"


def load_engine_defines(port_root: Path, manifest: dict) -> tuple[list[str], dict[str, list[tuple[str, ...]]]]:
    """EngineDefines.json — таблица вариантов движка. Отсутствие файла допустимо."""
    always = normalize_defines(manifest.get("always_defines", []))
    path = port_root / "EngineDefines.json"
    if not path.is_file():
        return always, {}

    data = json.loads(path.read_text(encoding="utf-8-sig"))
    always = normalize_defines(data.get("always", always))
    records = data.get("targets")
    if not isinstance(records, list):
        raise ValueError(f"{path}: отсутствует массив targets")

    variants: dict[str, list[tuple[str, ...]]] = {}
    for record in records:
        rel_source = record.get("source")
        if not rel_source:
            raise ValueError(f"{path}: запись без source: {record!r}")
        source = port_root / rel_source
        if not source.is_file():
            raise FileNotFoundError(f"{path}: исходник из таблицы дефайнов не найден: {rel_source}")
        defines = tuple(normalize_defines(record.get("defines", [])))
        variants.setdefault(rel_source.replace("\\", "/"), []).append(defines)

    return always, variants


def load_targets(
    shader_dir: Path,
    only: str,
    use_engine_defines: bool = True,
) -> tuple[list[Target], list[str], Path, Path, list[str]]:
    manifest_path = find_manifest(shader_dir)
    if not manifest_path:
        raise FileNotFoundError(f"Shaders.json не найден рядом с {shader_dir}")

    port_root = manifest_path.parent.resolve()
    repo_root = port_root.parent
    manifest = json.loads(manifest_path.read_text(encoding="utf-8-sig"))
    raw_targets = manifest.get("targets")
    if not isinstance(raw_targets, list):
        raise ValueError(f"{manifest_path}: отсутствует массив targets")

    always_defines, engine_variants = load_engine_defines(port_root, manifest)
    if not use_engine_defines:
        engine_variants = {}

    base_targets = []
    manifest_sources: set[Path] = set()
    base_rel_sources: set[str] = set()

    for item in raw_targets:
        stage = item.get("stage")
        entry = item.get("entry", "main")
        raw_source = item.get("source")
        if stage not in ("vs", "ps") or not raw_source or not entry:
            raise ValueError(f"{manifest_path}: некорректная цель: {item!r}")

        source = resolve_source(raw_source, repo_root, port_root)
        if source is None:
            raise FileNotFoundError(f"{manifest_path}: исходник не найден: {raw_source}")
        if not is_under(source, shader_dir):
            continue

        rel_source = source.relative_to(port_root).as_posix()
        manifest_sources.add(source)
        base_rel_sources.add(rel_source)
        inline_defines = tuple(normalize_defines(item.get("defines", [])))
        base_targets.append((source, rel_source, stage, entry, inline_defines))

    if use_engine_defines and engine_variants:
        relevant_engine_sources = {
            rel for rel in engine_variants
            if is_under((port_root / rel).resolve(), shader_dir)
        }
        missing = sorted(relevant_engine_sources - base_rel_sources)
        if missing:
            raise ValueError(
                f"{port_root / 'EngineDefines.json'}: источники есть в таблице дефайнов, "
                f"но отсутствуют в Shaders.json: {', '.join(missing)}"
            )

    needle = only.lower()
    targets: list[Target] = []
    for source, rel_source, stage, entry, inline_defines in base_targets:
        if needle and needle not in rel_source.lower() and needle not in entry.lower():
            continue
        define_sets = engine_variants.get(rel_source)
        if define_sets is None:
            define_sets = [inline_defines]
        for defines in define_sets:
            targets.append(Target(source=source, rel_source=rel_source, stage=stage, entry=entry, defines=defines))

    skipped: list[str] = []
    for path in sorted(shader_dir.rglob("*")):
        if not path.is_file() or path.suffix.lower() not in (".hlsl", ".fx"):
            continue
        resolved = path.resolve()
        if resolved not in manifest_sources:
            skipped.append(resolved.relative_to(port_root).as_posix()
                           if is_under(resolved, port_root) else str(resolved))

    return targets, skipped, port_root, manifest_path, always_defines


def group_variants(targets: list[Target]) -> "OrderedDict[tuple[str, tuple[str, ...]], list[Target]]":
    groups: OrderedDict[tuple[str, tuple[str, ...]], list[Target]] = OrderedDict()
    for target in targets:
        groups.setdefault(target.variant_key, []).append(target)
    return groups


def decode_output(data: bytes) -> str:
    if not data:
        return ""
    encodings = ["utf-8", locale.getpreferredencoding(False) or "utf-8", "cp1251", "cp866"]
    for encoding in dict.fromkeys(encodings):
        try:
            return data.decode(encoding)
        except (UnicodeDecodeError, LookupError):
            continue
    return data.decode("utf-8", errors="replace")


def first_error(text: str) -> str:
    for line in text.splitlines():
        stripped = line.strip()
        if re.search(r"\berror\b", stripped, re.IGNORECASE):
            return stripped
    lines = [line.strip() for line in text.splitlines() if line.strip()]
    return lines[0] if lines else "(без текста)"


def count_warnings(text: str) -> int:
    return sum(1 for line in text.splitlines() if re.search(r"\bwarning\b", line, re.IGNORECASE))


def github_escape(value: str) -> str:
    return value.replace("%", "%25").replace("\r", "%0D").replace("\n", "%0A")


def emit_github_error(message: str, file: str = "", title: str = "") -> None:
    if os.environ.get("GITHUB_ACTIONS") != "true":
        return
    props = []
    if file:
        props.append("file=" + github_escape(file))
    if title:
        props.append("title=" + github_escape(title))
    prefix = "::error" + (" " + ",".join(props) if props else "") + "::"
    print(prefix + github_escape(message), flush=True)


def write_github_summary(
    ok_builds: int,
    failed: list[dict],
    warnings_total: int,
    skipped: list[str],
    variant_count: int,
    build_count: int,
    unique_sources: int,
    sources_with_defines: int,
) -> None:
    summary_path = os.environ.get("GITHUB_STEP_SUMMARY")
    if not summary_path:
        return
    lines = [
        "## Shader compile check",
        "",
        f"- Variants: {variant_count}",
        f"- Entry-point builds: {build_count}",
        f"- OK builds: {ok_builds}",
        f"- Failed builds: {len(failed)}",
        f"- Unique sources: {unique_sources}",
        f"- Sources with variant defines: {sources_with_defines}",
        f"- Warnings: {warnings_total}",
        f"- Skipped library files: {len(skipped)}",
    ]
    if failed:
        lines += ["", "| Source | Entry | Profile | Defines | Error |", "|---|---|---|---|---|"]
        for result in failed[:100]:
            message = result["message"].replace("|", "\\|").replace("\n", " ")
            defines = defines_label(result.get("variant_defines", []))
            lines.append(f"| {result['source']} | {result['entry']} | {result['profile']} | {defines} | {message} |")
    Path(summary_path).write_text("\n".join(lines) + "\n", encoding="utf-8")


def output_path(out_dir: Path, target: Target, profile: str, entry: str, defines: list[str]) -> Path:
    base = out_dir / Path(target.rel_source).parent
    suffix = ""
    if defines:
        digest = hashlib.sha1(",".join(defines).encode("utf-8")).hexdigest()[:10]
        slug = re.sub(r"[^A-Za-z0-9_.=-]+", "_", "_".join(defines))[:80]
        suffix = f"_{slug}_{digest}" if slug else "_" + digest
    safe_entry = re.sub(r"[^A-Za-z0-9_.-]+", "_", entry)
    return base / f"{Path(target.rel_source).stem}_{safe_entry}_{profile}{suffix}.cso"


def compile_one(
    fxc: str,
    target: Target,
    profile: str,
    out_dir: Path,
    port_root: Path,
    always_defines: list[str],
    cli_defines: list[str],
    debug: bool,
    warnings_as_errors: bool,
    timeout: int,
) -> dict:
    effective_defines = normalize_defines([*always_defines, *target.defines, *cli_defines])
    out_path = output_path(out_dir, target, profile, target.entry, effective_defines)
    out_path.parent.mkdir(parents=True, exist_ok=True)

    args = [fxc, "/nologo", "/T", profile, "/E", target.entry, "/Zpc"]
    include_dirs: list[Path] = []
    for inc in (port_root, target.source.parent):
        if inc not in include_dirs:
            include_dirs.append(inc)
    for inc in include_dirs:
        args += ["/I", str(inc)]
    if debug:
        args += ["/Od", "/Zi"]
    else:
        args += ["/O2"]
    if warnings_as_errors:
        args.append("/WX")
    for define in effective_defines:
        args += ["/D", define]
    args += ["/Fo", str(out_path), str(target.source)]

    result = {
        "source": target.rel_source,
        "entry": target.entry,
        "stage": target.stage,
        "profile": profile,
        "defines": effective_defines,
        "variant_defines": list(target.defines),
        "always_defines": list(always_defines),
        "success": False,
        "output": str(out_path),
        "command": args,
        "warnings": 0,
        "message": "",
        "log": "",
    }

    try:
        proc = subprocess.run(args, capture_output=True, timeout=timeout)
    except subprocess.TimeoutExpired:
        result["message"] = f"timeout after {timeout}s"
        result["log"] = result["message"]
        return result

    text = decode_output(proc.stdout) + decode_output(proc.stderr)
    result["log"] = text
    result["warnings"] = count_warnings(text)
    result["success"] = proc.returncode == 0
    if not result["success"]:
        result["message"] = first_error(text)
    return result


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Собрать цели HLSL_D3D11 из Shaders.json/EngineDefines.json через fxc.exe без запуска игры."
    )
    parser.add_argument("shader_dir", help="каталог HLSL_D3D11 или его подкаталог")
    parser.add_argument("--only", default="", help="компилировать только цели, где путь или entry содержит подстроку")
    parser.add_argument("--fxc", default="", help="путь к fxc.exe; по умолчанию PATH и Windows SDK")
    parser.add_argument("--out", default="", help="каталог для .cso; по умолчанию временный каталог")
    parser.add_argument("--shader-model", type=int, choices=(4, 5), default=DEFAULT_SHADER_MODEL,
                        help="поколение профилей: 4 => vs_4_0/ps_4_0, 5 => vs_5_0/ps_5_0")
    parser.add_argument("--profile", default="", choices=sorted(SUPPORTED_PROFILES),
                        help="переопределить профиль для всех выбранных целей")
    parser.add_argument("--define", action="append", default=[], metavar="NAME[=VALUE]",
                        help="дополнительный дефайн препроцессора; можно повторять или перечислять через запятую")
    parser.add_argument("--no-engine-defines", action="store_true",
                        help="игнорировать EngineDefines.json и собрать только базовые цели Shaders.json")
    parser.add_argument("--debug", action="store_true", help="/Od /Zi вместо /O2")
    parser.add_argument("--warnings-as-errors", action="store_true", help="добавить /WX")
    parser.add_argument("--timeout", type=int, default=120, help="таймаут одной сборки в секундах")
    parser.add_argument("--report", default="", help="записать JSON-отчёт в указанный файл")
    parser.add_argument("--list", action="store_true", help="только показать выбранные варианты, без поиска fxc")
    parser.add_argument("--verbose", action="store_true", help="печатать успешные сборки")
    return parser


def main(argv: list[str]) -> int:
    for stream in (sys.stdout, sys.stderr):
        try:
            stream.reconfigure(encoding="utf-8", errors="replace")
        except (AttributeError, ValueError):
            pass

    args = build_parser().parse_args(argv)
    shader_dir = Path(args.shader_dir).expanduser().resolve()

    if not shader_dir.is_dir():
        print(f"Каталог шейдеров не найден: {shader_dir}", file=sys.stderr)
        return 2

    try:
        targets, skipped, port_root, manifest_path, always_defines = load_targets(
            shader_dir, args.only, use_engine_defines=not args.no_engine_defines
        )
        cli_defines = normalize_defines(args.define)
    except (OSError, ValueError, FileNotFoundError) as exc:
        print(str(exc), file=sys.stderr)
        return 2

    if not targets:
        print(f"Нет целей компиляции в {shader_dir} (filter={args.only!r}).", file=sys.stderr)
        return 2

    groups = group_variants(targets)
    unique_sources = len({target.rel_source for target in targets})
    sources_with_defines = len({target.rel_source for target in targets if target.defines})

    print(f"манифест: {manifest_path}")
    print(f"шейдеры:  {shader_dir}")
    print(f"целей (вариантов): {len(groups)}")
    print(f"entry-point builds: {len(targets)}")
    print(f"уникальных исходников: {unique_sources}; из них с дефайнами: {sources_with_defines}")
    print(f"профиль:  {args.profile or f'*_{args.shader_model}_0'}")
    print(f"always:   {defines_label(always_defines)}")
    if cli_defines:
        print(f"extra:    {defines_label(cli_defines)}")

    if args.list:
        for (rel_source, defines), group in groups.items():
            if len(group) == 1:
                target = group[0]
                detail = f"{target.profile(args.shader_model, args.profile)} :: {target.entry}"
            else:
                stages = "/".join(sorted({target.stage for target in group}))
                entries = ", ".join(target.entry for target in group)
                detail = f"{stages} :: {len(group)} entries ({entries})"
            print(f"  {rel_source} [{detail}] defines: {defines_label(defines)}")
        if skipped:
            print("Пропущено (нет отдельной цели в манифесте — библиотеки/заголовки):")
            for item in skipped:
                print(f"  {item}")
        return 0

    fxc = find_fxc(args.fxc)
    if not fxc:
        print("fxc.exe не найден.", file=sys.stderr)
        print("Поставьте Windows SDK или укажите путь: --fxc <...>\\x64\\fxc.exe", file=sys.stderr)
        print("Либо запустите из 'x64 Native Tools Command Prompt for VS'.", file=sys.stderr)
        return 2

    out_dir = Path(args.out).expanduser().resolve() if args.out else Path(tempfile.mkdtemp(prefix="tow_shader_check_"))
    out_dir.mkdir(parents=True, exist_ok=True)
    print(f"fxc:      {fxc}")
    print(f"вывод:    {out_dir}")
    print("")

    results: list[dict] = []
    ok_builds = 0
    failed: list[dict] = []
    warnings_total = 0
    failed_groups: set[tuple[str, tuple[str, ...]]] = set()

    for target in targets:
        profile = target.profile(args.shader_model, args.profile)
        result = compile_one(
            fxc=fxc,
            target=target,
            profile=profile,
            out_dir=out_dir,
            port_root=port_root,
            always_defines=always_defines,
            cli_defines=cli_defines,
            debug=args.debug,
            warnings_as_errors=args.warnings_as_errors,
            timeout=args.timeout,
        )
        results.append(result)
        warnings_total += result["warnings"]

        label = defines_label(result["defines"])
        if result["success"]:
            ok_builds += 1
            if args.verbose:
                print(f"  ok    {target.rel_source} :: {target.entry} [{profile}] defines: {label}")
            continue

        failed.append(result)
        failed_groups.add(target.variant_key)
        workspace = Path(os.environ.get("GITHUB_WORKSPACE", str(port_root.parent)))
        try:
            annotation_file = target.source.relative_to(workspace).as_posix()
        except ValueError:
            annotation_file = target.rel_source
        emit_github_error(result["message"], annotation_file, f"{profile} {target.entry} [{label}]")
        print(f"ОШИБКА  {target.rel_source} :: {target.entry} [{profile}] defines: {label}")
        for line in result["log"].splitlines():
            if line.strip():
                print("        " + line.strip())

    ok_groups = len(groups) - len(failed_groups)
    print("")
    print(
        f"Собрано: {ok_builds} успешно, {len(failed)} с ошибками; "
        f"целей (вариантов): {len(groups)} (успешно {ok_groups}, с ошибками {len(failed_groups)}); "
        f"entry-point builds: {len(targets)}; уникальных исходников: {unique_sources}; "
        f"из них с дефайнами: {sources_with_defines}; предупреждений: {warnings_total}"
    )

    if skipped:
        print("Пропущено (нет отдельной цели в манифесте — библиотеки/заголовки):")
        for item in skipped:
            print(f"  {item}")

    write_github_summary(
        ok_builds, failed, warnings_total, skipped,
        len(groups), len(targets), unique_sources, sources_with_defines,
    )

    if args.report:
        report_path = Path(args.report).expanduser().resolve()
        report_path.parent.mkdir(parents=True, exist_ok=True)
        report = {
            "shader_dir": str(shader_dir),
            "manifest": str(manifest_path),
            "engine_defines": str(port_root / "EngineDefines.json") if (port_root / "EngineDefines.json").is_file() else "",
            "fxc": fxc,
            "shader_model": args.shader_model,
            "profile_override": args.profile,
            "always_defines": always_defines,
            "extra_defines": cli_defines,
            "variant_count": len(groups),
            "build_count": len(targets),
            "unique_sources": unique_sources,
            "sources_with_variant_defines": sources_with_defines,
            "ok": ok_builds,
            "failed": len(failed),
            "ok_variants": ok_groups,
            "failed_variants": len(failed_groups),
            "warnings": warnings_total,
            "skipped": skipped,
            "results": results,
        }
        report_path.write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")
        print(f"JSON-отчёт: {report_path}")

    if failed:
        print("")
        print("Сводка ошибок:")
        for result in failed:
            print(f"  {result['source']} :: {result['entry']} [{result['profile']}] defines: {defines_label(result['defines'])}")
            print(f"      {result['message']}")
        return 1

    print("Все выбранные шейдеры собрались.")
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main(sys.argv[1:]))
    except Exception as exc:
        emit_github_error(f"compile_shaders.py failed: {type(exc).__name__}: {exc}")
        raise

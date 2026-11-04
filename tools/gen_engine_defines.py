#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Таблица дефайнов, с которыми core.dll реально компилирует шейдеры.

Зачем: проверка в репозитории шейдеров собирает всё без дефайнов, а движок просит
варианты (`-D SHADOW -D COMPAREZ ...`). Половина кода порта живёт под #ifdef и в CI
не компилируется. Скрипт печатает JSON, который можно положить в репозиторий шейдеров
как EngineDefines.json.

Использование:
    python tools/gen_engine_defines.py <каталог HLSL_D3D11 с Shaders.json> [--out файл]
"""

import argparse
import json
import os
import sys

# SpeedTreeDefaults.hlsli = то, что SpeedTreeDefines.h держит включённым, плюс то,
# что SpeedTreeForest.cpp всегда дописывает в строку дефайнов.
ST_BASE = [
    "USE_SHADOWS",              # SpeedTreeForest.cpp:3775, безусловно
    "SELF_SHADOW_LAYER",        # SpeedTreeDefines.h:12
    "BILLBOARD_NORMAL_MAPPING", # SpeedTreeDefines.h:8
    "BRANCH_NORMAL_MAPPING",    # :5
    "FROND_NORMAL_MAPPING",     # :6
    "LEAF_NORMAL_MAPPING",      # :7
    "NUM_WIND_MATRICES=7",      # SpeedTreeForest.cpp:3779 (значение с CPU)
    "MAX_NUM_LEAF_ANGLES=20",   # :3783
]
ST_FOG = ST_BASE + ["USE_FOG"]                        # :3736, если задан диапазон тумана
ST_360 = ST_BASE + ["SUPPORT_360_BILLBOARDS"]         # :3797, если хватает 360-биллбордов
ST_FOG_360 = ST_BASE + ["USE_FOG", "SUPPORT_360_BILLBOARDS"]

# MegaPlane: CumulusClouds.cpp:1205 — битовая маска opshad, 5 бит.
# SHADOW всегда идёт с COMPAREZ: HS_SHADERS_NV в D3D11 возвращает FALSE
# (HAL/THALDevice_D3D11.cpp:2293).
MEGA_BITS = ["CLIPPING", "USE_NOISE", "USE_FOG", "USE_BUMP"]
MEGA = []

for mask in range(1 << len(MEGA_BITS)):
    base = [MEGA_BITS[i] for i in range(len(MEGA_BITS)) if mask >> i & 1]
    MEGA.append(base)
    MEGA.append(base + ["SHADOW", "COMPAREZ"])

# (префикс имени файла без расширения, наборы дефайнов)
RULES = [
    ("MegaPlane",        MEGA),
    ("ObjectsOnePass",   [["USE_SPECULAR", "USE_SHADOWS"],
                          ["USE_SPECULAR", "USE_SHADOWS", "USE_SKINNING"]]),
    ("ObjectsZPass",     [[], ["USE_SKINNING"]]),
    ("ObjectsDepthPass", [[], ["USE_SKINNING"]]),
    ("SpeedTree/",       [ST_BASE, ST_FOG, ST_360, ST_FOG_360]),
    # TreeProp.cpp:3448 (VP всегда без COMPAREZ — он нужен только пиксельному),
    # :3489 (с туманом), :3558 (без теней), :3585 (z-pass).
    ("TreeVP",           [["SHADOW"], ["SHADOW", "FOG"], ["FOG"], ["ZPASS"]]),
    ("TreeFP",           [["SHADOW", "COMPAREZ"], ["SHADOW", "COMPAREZ", "FOG"],
                          ["FOG"], ["ZPASS"]]),
    # Деформация ландшафта грузит RoadVP/RoadFP (DeformationManager.h:23), а не
    # DeformationFP/VP.hlsl — те в этой сборке не загружаются вовсе.
    ("TreeTrunk",        [["ZPASS"], ["FOG"], []]),
    ("GrassMainPass",    [["FULL"], ["FULL", "COMPAREZ"]]),
    ("GrassDepthPass",   [["FULL"]]),
    # RoadVP/RoadFP — и декали (effects3d/trackeff3d.cpp:220, "-DSPECULAR -DCOMPAREZ"),
    # и деформация ландшафта (landscape/DeformationManager.cpp:181/221).
    ("RoadVP",           [["SHADOW", "SPECULAR", "FOG"], ["SPECULAR", "FOG"],
                          ["SPECULAR", "COMPAREZ"]]),
    ("RoadFP",           [["SHADOW", "SPECULAR", "COMPAREZ", "FOG"], ["SPECULAR", "FOG"],
                          ["SPECULAR", "COMPAREZ"]]),
    ("FogTest",          [["SIMPLE_FOG"]]),
    ("EffectShader2",    [["SOFT_PARTICLES"]]),
]


def rules_for(rel_source):
    base = os.path.splitext(os.path.basename(rel_source))[0]

    for prefix, sets in RULES:
        if prefix.endswith("/"):
            if prefix in rel_source:
                return sets
        elif base.startswith(prefix):
            return sets

    return [[]]


def main(argv):
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("shader_dir", help="каталог HLSL_D3D11 с Shaders.json")
    parser.add_argument("--out", default="", help="куда писать JSON (по умолчанию stdout)")
    args = parser.parse_args(argv)

    manifest_path = os.path.join(args.shader_dir, "Shaders.json")

    if not os.path.isfile(manifest_path):
        print("Не найден %s" % manifest_path)
        return 2

    with open(manifest_path, "r", encoding="utf-8-sig") as handle:
        manifest = json.load(handle)

    sources = sorted({target["source"] for target in manifest.get("targets", [])})
    targets = []
    bare = []

    for source in sources:
        rel = source.replace("HLSL_D3D11/", "", 1)

        for defines in rules_for(rel):
            targets.append({"source": rel, "defines": defines})
            if not defines:
                bare.append(rel)

    result = {
        "_comment": "Дефайны, с которыми core.dll реально компилирует шейдеры. "
                    "Сгенерировано tools/gen_engine_defines.py; см. docs/SHADER_CI_DEFINE_TASK.md.",
        "always": ["SM40=1"],
        "targets": targets,
    }

    text = json.dumps(result, ensure_ascii=False, indent=1)

    if args.out:
        with open(args.out, "w", encoding="utf-8") as handle:
            handle.write(text + "\n")
        print("записано: %s" % args.out)
    else:
        print(text)

    unique = {t["source"] for t in targets}
    with_defines = [t for t in targets if t["defines"]]

    print("источников: %d | целей: %d (с дефайнами: %d, базовых: %d) | файлов с дефайнами: %d"
          % (len(sources), len(targets), len(with_defines),
             len(targets) - len(with_defines), len({t["source"] for t in with_defines})))
    print("без правил: %d" % len(set(bare)))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))

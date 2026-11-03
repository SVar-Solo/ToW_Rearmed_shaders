# Аудит D3D11: почему вместо текстур виден туман или чернота

Проверяемая ветка: `arena/9e4ce3d4-tow-rearmed-shaders`.  
Базовое состояние: `077c957` — merge PR #2 `fix/sv-position-last`.  
Каталог аудита: `HLSL_D3D11/`. Исходные `HLSL/` и `SMAA/` не изменялись.

## Краткий вывод

1. **PR #2 сам по себе не должен превращать текстуры в туман или черноту.** Его diff меняет только порядок поля `SV_Position` в структурах VS/PS и пустые строки. Он не меняет слоты `tN/sN/bN`, формулы тумана, освещение или выборки текстур. Если после него кадр стал рисоваться, но с неправильными цветами, вероятнее всего раньше отрисовка падала на linkage mismatch, а теперь стали видны ошибки привязки ресурсов/констант в D3D11-рендере.

2. **“Цвет тумана вместо текстуры”** в первую очередь указывает на:
   - SRV тумана/неба попал в слот базовой текстуры (`t0`) или базовая текстура не привязана;
   - `SamplerState` и `ShaderResourceView` перепутаны местами: в D3D11 текстура идёт в `tN`, сэмплер — в `sN`;
   - экранный проход тумана `SSFog_PS` рисует поверх сцены с неверным depth/blend;
   - `SSFog_PS` получил не тот формат глубины: шейдер ожидает линейную положительную глубину вида, а не нормализованный D3D11 depth `[0,1]`;
   - VS и PS скомпилированы с разными fog-дефайнами.

3. **“Чернота вместо текстуры”** в первую очередь указывает на:
   - не заполнены **пиксельные** cbuffer: `AmbientColor`, `DiffuseColor`, `ColorScale`, `koeffNdotL`, `fSkyMultiplier`;
   - константы заданы только через `VSSetConstantBuffers`, но не через `PSSetConstantBuffers`;
   - `GBufferTex` не привязан или содержит не тот буфер;
   - `ColorScale.rgb/a` равен нулю;
   - cbuffer заполнен старым D3D9-массивом регистров без учёта HLSL-упаковки;
   - матрицы загружены без согласования `column_major`/transpose.

## Исправления, внесённые в `HLSL_D3D11/`

| Файл | Проблема | Исправление |
|---|---|---|
| `DeformationVP.hlsl` | Порт добавил `saturate(OUT.Color1)`, но `Color1` есть только при `SPECULAR`. Без `SPECULAR` это ошибка компиляции. | Clamp обёрнут в `#ifdef SPECULAR`. Также явно взято `pos_new.xyz` в specular-векторе. |
| `MegaPlaneVS.hlsl` | `saturate(OUT.FogColor)` выполнялся без `USE_FOG`, когда поля нет. | Clamp обёрнут в `#ifdef USE_FOG`. Добавлен alias `USE_FOG1 -> USE_FOG`. |
| `TreeTrunkVS.hlsl` | В варианте `ZPASS` выполнялся `saturate(OUT.color)`, хотя `color` есть только в не-ZPASS. | Clamp обёрнут в `#ifndef ZPASS`. |
| `TreeVP.hlsl` | В `ZPASS` выполнялись clamp для отсутствующих `COL0/COL1`; также был некорректный `#endif PSSM`. | Clamp обёрнут в `#ifndef ZPASS`; директива исправлена на `#endif // PSSM`. |
| `WaterVP.hlsl` | Два выхода имели одну семантику `TEXCOORD2`. | `tex3` получил `TEXCOORD3` и детерминированную инициализацию. |
| `SpeedTree/DepthFrondsPS.hlsl`, `SpeedTree/DepthFrondsFASTPS.hlsl` | При дефолтном `INTERMEDIATE_FRONDBRANCH_FADING` читался несуществующий `In.vNormal.w` в неиспользуемую переменную `fade`. | Мёртвое чтение удалено; результат depth-pass не изменился. |
| `ObjectsOnePassVS/PS.hlsl`, `RoadVP/FP.hlsl`, `MegaPlaneVS/PS.hlsl` | Legacy-варианты `USE_FOG1`/`FOG1` могли включать расчёт тумана без объявления ресурсов/интерполяторов, которые объявлены под `USE_FOG`/`FOG`. | Добавлены совместимые alias: `USE_FOG1 -> USE_FOG`, `FOG1 -> FOG`. |
| `MegaPlanePS.hlsl`, `RoadVP.hlsl` | Неявные усечения векторов, допустимые старым HLSL, но неоднозначные для строгих фронтендов. | Явные `.xy` без изменения математики. |
| `SMAA/SMAA.hlsl` | `fxc` error X3003: redefinition of `PointSampler` — рядом с новым `SamplerState : register(s1)` остался legacy sampler-state block. | Legacy-блок удалён; остаются CPU-создаваемые `LinearSampler s0` и `PointSampler s1`. |
| `SpeedTree/Billboards0PS.hlsl`, `Billboards1PS.hlsl`, `BillboardsPS.hlsl`, `DepthBillboardsPS.hlsl` | Legacy `tex2D(..., dsdx, dsdy)` был перенесён как `Texture2D.Sample(..., dsdx, dsdy)`. На SM4 это ошибка X3535, а семантически это gradient sampling. | Заменено на `Texture2D.SampleGrad(..., dsdx, dsdy)`. |
| `SpeedTree/ZPassBillboardsVS.hlsl` | При `USE_FOG` функция `FogValue` использовала необъявленный `g_vFogParams` (`fxc` X3004). | Добавлен условный cbuffer `ZPassBillboardsVS_CB2 : register(b2)` с `float3 g_vFogParams`; манифест обновлён. |

Эти правки устраняют реальные ошибки вариантов и согласуют fog-дефайны. Они **не заменяют** проверку привязок ресурсов в движке.

## Критические слоты ресурсов

### `ObjectsOnePassPS.hlsl`

| Ресурс | Слот | Назначение |
|---|---:|---|
| `decal` | `t0` / `s0` | Базовая текстура объекта. Если сюда попадает SkyMap/FogColor — объект будет цвета тумана. |
| `BumpMap` | `t1` / `s1` | Normal/bump. |
| `GBufferTex` | `t2` / `s2` | Буфер теней/ambient. Если не привязан или нулевой — освещение может стать чёрным. |
| `SkyMap` | `t3` / `s3` | Куб тумана, только при fog-варианте. Не должен попадать в `t0`. |

Константы PS:

| cbuffer | Поля | Что будет при нуле |
|---|---|---|
| `ObjectsOnePassPS_CB0`, `b0` | `koeffNdotL`, `fSkyMultiplier`, `gRTSize` | Неверный diffuse/shadow UV; `koeffNdotL.z = 0` убивает diffuse. |
| `ObjectsOnePassPS_CB1`, `b1` | `AmbientColor` | Нет ambient-освещения. |
| `ObjectsOnePassPS_CB2`, `b2` | `SpecularColor` | Только для `USE_SPECULAR`. |
| `ObjectsOnePassPS_CB3`, `b3` | `DiffuseColor`, `ColorScale` | `DiffuseColor = 0` или `ColorScale = 0` даёт чёрную текстуру. |

Ключевая формула:

```hlsl
float3 LightValue = lerp(AmbientColor.rgb * gbuffer.g,
                         DiffuseColor.rgb * koeffNdotL.z,
                         light);
LightValue = decalCS.rgb * LightValue;
```

Если `decalCS.rgb`, `AmbientColor`, `DiffuseColor`, `gbuffer.g` или `koeffNdotL.z` нулевые/неверные, базовая текстура будет чёрной даже при правильном `t0`.

### `SSFog_PS.hlsl`

| Ресурс | Слот | Назначение |
|---|---:|---|
| `DepthMap` | `t0` / `s0` | Глубина сцены. |
| `SkyCube` | `t1` / `s1` | Куб цвета тумана/неба. |

Важно: `SSFog_PS` использует глубину так:

```hlsl
float depth = DepthMap.Sample(...).r;
float z = -depth;
...
if (depth > 10000) ...
```

Это контракт **линейной положительной глубины вида в мировых единицах**, унаследованный от старого рендера. Обычный D3D11 depth-buffer SRV отдаёт нормализованную глубину `[0,1]`. Если привязать его напрямую, реконструкция мирового положения и плотность тумана будут неверными.

Также проверьте:
- `SkyCube` должен быть именно `TextureCube` SRV, не `Texture2D`;
- blend-state экранного прохода должен использовать alpha тумана, а не рисовать opaque-прямоугольник;
- `fSkyMultiplier` и fog-константы в `b0` должны быть заполнены;
- `restoreWorldSpace` содержит старую инверсию X: `(1.0f - IN.texCoord.x)`. Это нужно сверить с ориентацией fullscreen-quad и D3D11 UV.

### `HDRFinalPS.hlsl`

В текущем коде вызов `getFogedPixel(IN, c)` в `main` закомментирован. То есть финальный HDR-проход **не должен** сам добавлять туман. Если туман появляется после HDR, ищите его в `SSFog_PS`/`SSFogCopy_PS` или в per-object fog.

Не включайте `getFogedPixel` обратно без исправления depth-контракта и UV-реконструкции.

### `MegaPlanePS.hlsl`

Слоты terrain:
`IndirTex t0`, `MegaCacheTex t1`, `GBufferTex t2`, `typeMap t3`, `megaNoise t4`, `maskDSDT t5`, `SkyMap t6`, `NormalMap t7`, `CommonNoise t8`, `FarMainTex t9`.

Если рендерер по старой памяти привязывает fog/sky cube в один из первых слотов, terrain может получить цвет тумана вместо megatexture.

### `TreeFP.hlsl`

Обычный вариант:
`BumpTex t0`, `TreeTex t1`, `ShadowMap t2`, `SkyMap t3`.

Вариант `ZPASS`:
`TreeTex t0`.

Это разные раскладки. Нельзя использовать одну и ту же карту привязок для обоих вариантов.

## Fog-дефайны

Legacy-имена:
- `USE_FOG` и `USE_FOG1`;
- `FOG` и `FOG1`.

В исправленной версии `USE_FOG1` подразумевает `USE_FOG`, а `FOG1` подразумевает `FOG`. Но VS и PS одного прохода всё равно должны компилироваться с одним и тем же набором feature-дефайнов.

Примеры:

```powershell
cd HLSL_D3D11
.\Compile-D3D11.ps1 -Define USE_FOG,USE_SHADOWS
.\Compile-D3D11.ps1 -Define FOG,SHADOW,SPECULAR
.\Compile-D3D11.ps1 -Define ZPASS
```

Для SpeedTree числовые константы и always-on material/layer флаги заданы в
`SpeedTreeDefaults.hlsli`, а feature-варианты (`USE_FOG`,
`SUPPORT_360_BILLBOARDS` и т.п.) приходят из `EngineDefines.json`. Безусловно
включать `INTERMEDIATE_FRONDBRANCH_FADING`, `HORZ_BILLBOARDS`,
`BRANCH_DETAIL_LAYER`, `UPVECTOR_POS_Y` в `.hlsli` нельзя: в движке они
выключены/опциональны.

## Что проверено в этой сессии

- Diff PR #2: только перенос `SV_Position` и пустые строки; ресурсы/константы/формулы не менялись.
- Статический валидатор: `OK: 149 HLSL/HLSLI files passed static checks`.
- Повторная проверка conditional `saturate`: отсутствующих полей больше нет.
- Добавлен оффлайн-компилятор `tools/compile_shaders.py`: цели берутся из `Shaders.json`, профили по умолчанию `vs_4_0/ps_4_0`, есть `--shader-model 5`, `--only`, `--define`, `--report`, `--list`.
- GitHub Actions `Shader compile check`, запуск [41603427488](https://github.com/SVar-Solo/ToW_Rearmed_shaders/actions/runs/41603427488): **success** на `windows-latest` для обеих матриц:
  - `fxc SM4` — `vs_4_0/ps_4_0`;
  - `fxc SM5` — `vs_5_0/ps_5_0`.
- Артефакты CI: `shader-cso-sm4`, `shader-cso-sm5` (`.cso` + JSON-отчёты).
- GPU-тест и визуальное сравнение кадров в этой среде не выполнялись; linkage VS/PS, cbuffer layout и привязки SRV/sampler нужно проверять в движке / RenderDoc.

## Проверка вариантов с дефайнами движка

Добавлен `HLSL_D3D11/EngineDefines.json` (381 запись, `always: ["SM40=1"]`) и
генератор `tools/gen_engine_defines.py`. `tools/compile_shaders.py` теперь по
умолчанию собирает варианты из этой таблицы: один набор дефайнов — одна сборка.
Ориентиры: 381 вариант, 147 уникальных исходников, 72 исходника с дефайнами;
из-за 8 точек входа `SMAA/SMAA_Passes.hlsl` фактических `fxc`-сборок — 388.

Исправление, найденное variant CI: `TreeFP.hlsl` в варианте `ZPASS` пытался
компилировать неиспользуемую PSSM-функцию с `ShadowMap`, хотя `ShadowMap`
объявляется только вне `ZPASS`. Блок PSSM теперь guarded как
`#if defined(PSSM) && !defined(ZPASS)`; активный `ZPASS`-путь не изменён.

GitHub Actions `Shader compile check`, запуск
[41693867643](https://github.com/SVar-Solo/ToW_Rearmed_shaders/actions/runs/41693867643):
**success** на `windows-latest`, матрица SM4/SM5, job блокирующий.
Время шага компиляции: SM4 ≈ 11 с, SM5 ≈ 13 с; артефакты
`shader-cso-sm4` / `shader-cso-sm5` содержат `.cso` и `report.json` с `defines`.

Тесты покрытия вариантов:
- временный `#error` внутри `#ifdef SHADOW` в `MegaPlanePS.hlsl` —
  [41694232696](https://github.com/SVar-Solo/ToW_Rearmed_shaders/actions/runs/41694232696)
  упал на вариантах `MegaPlanePS` с `SHADOW COMPAREZ`;
- временный `#error` внутри `#ifdef USE_SHADOWS` в
  `SpeedTree/BillboardsPS.hlsl` —
  [41694543878](https://github.com/SVar-Solo/ToW_Rearmed_shaders/actions/runs/41694543878)
  упал на вариантах `BillboardsPS` с `USE_SHADOWS`.
После проверки тестовые строки откачены.

## Минимальный порядок диагностики на целевой машине

1. Включить D3D11 Debug Layer и сохранить все сообщения о linkage, input layout, SRV/sampler/cbuffer.
2. В RenderDoc выбрать плохой draw call и проверить:
   - какой SRV реально лежит в `t0`;
   - какой SamplerState лежит в `s0`;
   - заполнены ли PS cbuffer, особенно `ColorScale`, `AmbientColor`, `DiffuseColor`;
   - не рисуется ли поверх `SSFog_PS`/`SSFogCopy_PS`.
3. Временно отключить экранный fog-pass. Если текстуры становятся нормальными — проблема в `SSFog_PS` depth/blend/константах.
4. Временно вывести `decal.Sample(...)`. Если он нормальный, а итог чёрный — проблема в освещении/cbuffer/GBuffer.
5. Сверить матрицы: порт использует `column_major` и `/Zpc`; row-major D3DX-матрицы нужно транспонировать или согласовать упаковку.

## Что нужно для окончательного подтверждения

Если после этих правок симптом остаётся, нужны:
- код `HALD3D11`, где вызываются `VSSet/PSSetShaderResources`, `VSSet/PSSetSamplers`, `VSSet/PSSetConstantBuffers`;
- точные дефайны компиляции каждого VS/PS;
- лог D3D11 Debug Layer;
- RenderDoc-кадр плохого draw call.

Без кода привязки ресурсов нельзя доказать, какой именно `tN/bN` получает неверные данные в рантайме.

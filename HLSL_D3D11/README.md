# HLSL → D3D11

Отдельная версия шейдеров проекта ToW_Rearmed под Direct3D 11 / Shader Model 5.0.
Исходные каталоги `HLSL/` и `SMAA/` не изменялись.

## Состав

- `*.hlsl`, `SpeedTree/*.hlsl` — перенос всех 146 шейдеров из `HLSL/`.
- `SMAA/SMAA.hlsl` — библиотека SMAA с включённым путём `SMAA_HLSL_4`.
- `SMAA/SMAA_Passes.hlsl` — точки входа VS/PS вместо старых technique/pass из `SMAA.fx`.
- `SpeedTreeDefaults.hlsli` — единые настройки SpeedTree вместо `defines.cg`.
- `Shaders.json` — карта ресурсов, константных буферов и целей компиляции.
- `Compile-D3D11.ps1` / `.bat` — пакетная компиляция через `fxc.exe`.
- `Tools/validate_d3d11.py` — статическая проверка переноса.

## Что изменено

1. **Семантики.**
   - Выходная позиция вершинного шейдера: `POSITION` → `SV_Position`.
   - Входная позиция пиксельного шейдера: `POSITION` → `SV_Position`.
   - Цветовой выход PS: `COLOR` / `COLOR0` → `SV_Target0`.
   - Интерполяторы `COLOR0/1` сохранены, но в VS добавлен `saturate`, чтобы
     повторить клампинг D3D9.
2. **Текстуры и сэмплеры.**
   - `sampler2D` → `Texture2D` + `SamplerState`.
   - `samplerCUBE` → `TextureCube` + `SamplerState`.
   - `tex2D/texCUBE` → `Sample`, `tex2Dproj` → деление на `w` + `Sample`,
     `tex2Dlod` → `SampleLevel`.
   - Старый слот `sN` сохранён как `tN` для SRV и `sN` для сэмплера.
3. **Константы.**
   - Числовые `uniform` собраны в именованные `cbuffer` (`*_CB0`, `*_CB1`, …).
   - Матрицы объявлены как `column_major`, чтобы сохранить упаковку HLSL по
     умолчанию. Если рендерер загружает row-major матрицы D3DX, транспонируйте
     их при записи в cbuffer или измените упаковку согласованно.
   - Инициализированные `uniform`-массивы SpeedTree стали `static const`.
4. **SpeedTree.**
   - Все файлы включают `SpeedTreeDefaults.hlsli`.
   - Значения по умолчанию соответствуют `defines.cg`:
     `NUM_WIND_MATRICES=7`, `MAX_NUM_LEAF_ANGLES=20`, `NUM_360_IMAGES=32`.
   - Для своей конфигурации определите `SPEEDTREE_CUSTOM_CONFIG` и задайте
     макросы до включения файла.
5. **SMAA.**
   - Используется `SMAA_HLSL_4`.
   - Для поставляемого `AreaTexDX9.dds` выбран канал `sample.ra`.
     Если замените текстуру на DX10-вариант, задайте
     `SMAA_AREATEX_SELECT(sample) sample.rg`.
   - Сэмплеры `LinearSampler` (`s0`) и `PointSampler` (`s1`) создаются на CPU.

## Компиляция

Требуется Windows SDK с `fxc.exe`.

```powershell
cd HLSL_D3D11
.\Compile-D3D11.ps1
# или с явным путём:
.\Compile-D3D11.ps1 -FxcPath 'C:\Program Files (x86)\Windows Kits\10\bin\10.0.22621.0\x64\fxc.exe'
# отладочная сборка и дополнительные дефайны:
.\Compile-D3D11.ps1 -DebugBuild -Define USE_SKINNING,USE_SPECULAR
```

Результат: `Compiled/**/*.cso`. Каталог `Compiled/` не предназначен для Git.

Статическая проверка без Windows SDK:

```bash
python3 Tools/validate_d3d11.py
```

## Интеграция в рендерер

Одни шейдеры не переводят приложение на D3D11. Необходимо также:

- создавать `ID3D11VertexShader` / `ID3D11PixelShader` из `.cso`;
- строить input layout по семантикам VS (`POSITION`, `NORMAL`, `TEXCOORDn`,
  `COLORn`);
- привязывать SRV в `tN`, сэмплеры в `sN`, константные буферы в `bN`;
- заполнять cbuffer по reflection, а не копированием старого массива регистров
  D3D9: упаковка `float3`/скаляров в cbuffer отличается;
- заменить D3D9 render states на `ID3D11BlendState`, `ID3D11DepthStencilState`,
  `ID3D11RasterizerState`;
- для SMAA передавать `SMAA_RT_METRICS = (1/w, 1/h, w, h)` в `SMAA_Metrics`;
- для SMAA edge detection использовать non-sRGB SRV цвета, а для neighborhood
  blending — sRGB SRV, если прежний проход работал в sRGB.

`Shaders.json` содержит для каждого шейдера список текстур/сэмплеров и
константных буферов. Это карта соответствия, но точные смещения внутри cbuffer
следует брать из reflection скомпилированного шейдера.

## Диагностика тумана и чёрных текстур

Отдельный отчёт по симптомам «вместо текстур цвет тумана или чернота»:
[`D3D11_FOG_TEXTURE_AUDIT.md`](D3D11_FOG_TEXTURE_AUDIT.md). В нём перечислены
критические слоты `tN/sN/bN`, fog-дефайны, исправленные ошибки вариантов и
порядок проверки привязок ресурсов в D3D11-рендере.

## Ограничения

- Перенос сохраняет математическую логику исходников, но не является
  автоматической заменой всего D3D9-рендера.
- В среде подготовки не было Windows SDK / GPU, поэтому полноценная компиляция
  `fxc` и визуальное сравнение кадров должны быть выполнены на целевой машине.
- Фильтрация, address mode, sRGB и сравнение глубины задаются на CPU; старые
  HLSL-файлы не содержали полного описания этих состояний.

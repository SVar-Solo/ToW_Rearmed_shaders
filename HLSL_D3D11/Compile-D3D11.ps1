<#
.SYNOPSIS
    Compiles the D3D11 shader port with fxc (vs_5_0 / ps_5_0).
.EXAMPLE
    .\Compile-D3D11.ps1
    .\Compile-D3D11.ps1 -FxcPath 'C:\Program Files (x86)\Windows Kits\10\bin\10.0.22621.0\x64\fxc.exe'
    .\Compile-D3D11.ps1 -Define USE_SKINNING,USE_SPECULAR -DebugBuild
#>
[CmdletBinding()]
param(
    [string]$FxcPath,
    [string]$OutputDir,
    [switch]$DebugBuild,
    [string[]]$Define = @()
)

$ErrorActionPreference = 'Stop'
$root = $PSScriptRoot
$repo = Split-Path $root -Parent
if (-not $OutputDir) { $OutputDir = Join-Path $root 'Compiled' }

function Find-Fxc {
    $cmd = Get-Command fxc.exe -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }
    $roots = @()
    if (${env:ProgramFiles(x86)}) { $roots += Join-Path ${env:ProgramFiles(x86)} 'Windows Kits\10\bin' }
    if ($env:ProgramFiles) { $roots += Join-Path $env:ProgramFiles 'Windows Kits\10\bin' }
    foreach ($r in $roots) {
        if (Test-Path $r) {
            $found = Get-ChildItem -Path $r -Recurse -Filter fxc.exe -ErrorAction SilentlyContinue |
                Where-Object { $_.FullName -match '\\x64\\' } |
                Sort-Object FullName -Descending | Select-Object -First 1
            if ($found) { return $found.FullName }
        }
    }
    throw 'fxc.exe not found. Install the Windows SDK or pass -FxcPath.'
}

if (-not $FxcPath) { $FxcPath = Find-Fxc }
if (-not (Test-Path $FxcPath)) { throw "fxc.exe not found: $FxcPath" }

$manifest = Get-Content (Join-Path $root 'Shaders.json') -Raw | ConvertFrom-Json
$ok = 0
$failed = @()
foreach ($target in $manifest.targets) {
    $profile = if ($target.stage -eq 'vs') { 'vs_5_0' } else { 'ps_5_0' }
    $source = Join-Path $repo ($target.source -replace '/', '\')
    $relOut = $target.output -replace '^Compiled/', ''
    $out = Join-Path $OutputDir ($relOut -replace '/', '\')
    $outParent = Split-Path $out -Parent
    if (-not (Test-Path $outParent)) { New-Item -ItemType Directory -Path $outParent | Out-Null }

    $fxcArgs = @('/nologo', '/T', $profile, '/E', $target.entry, '/Zpc', '/I', $root, '/Fo', $out)
    if ($DebugBuild) { $fxcArgs += @('/Od', '/Zi') } else { $fxcArgs += '/O2' }
    foreach ($d in $Define) { $fxcArgs += @('/D', $d) }
    $fxcArgs += $source

    Write-Host "[$($target.stage)] $($target.source) :: $($target.entry)"
    & $FxcPath @fxcArgs
    if ($LASTEXITCODE -ne 0) {
        $failed += "$($target.source) :: $($target.entry)"
    } else {
        $ok++
    }
}

Write-Host ''
Write-Host "Compiled $ok / $($manifest.targets.Count) targets."
if ($failed.Count -gt 0) {
    Write-Host 'Failed targets:'
    $failed | ForEach-Object { Write-Host "  $_" }
    exit 1
}

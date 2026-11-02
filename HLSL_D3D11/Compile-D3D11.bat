@echo off
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Compile-D3D11.ps1" %*

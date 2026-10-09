@echo off
setlocal
start "XLink Codex Pets" powershell.exe -NoProfile -STA -WindowStyle Hidden -ExecutionPolicy Bypass -File "%~dp0scripts\Manager.ps1"

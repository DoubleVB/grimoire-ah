@echo off
title Profitmancer - WoW Forever
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Install-Profitmancer.ps1" -Uninstall
echo.
pause

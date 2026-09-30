@echo off
rem 一键还原迁移包到本机（用法: migrate-restore.bat [迁移包路径]；不带参数会提示输入）
set "PKG=%~1"
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0asp.ps1" migrate %PKG%
pause

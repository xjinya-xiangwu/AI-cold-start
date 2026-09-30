@echo off
rem 一键导出本机 agent 环境 -> 迁移包（零依赖，双击即用）
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0asp.ps1" export
pause

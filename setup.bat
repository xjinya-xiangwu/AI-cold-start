@echo off
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0asp.ps1" install
echo.
choice /C YN /M "Also install recommended MCPs? (context7 docs search + memory + thinking, zero-key)"
if errorlevel 2 goto skipmcp
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0asp.ps1" mcp install -Yes
:skipmcp
pause

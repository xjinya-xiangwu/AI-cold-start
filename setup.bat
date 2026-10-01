@echo off
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0asp.ps1" ui
echo.
echo [CLI fallback] If the picker page did not open, use:
echo   asp.ps1 install        (install packs)
echo   asp.ps1 mcp install    (install MCP presets)
pause

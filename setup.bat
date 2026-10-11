@echo off
chcp 65001 >nul
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0asp.ps1" ui
echo.
echo [备选] 如选择页未打开，可直接用命令行安装：
echo   powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0asp.ps1" install
echo   powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0asp.ps1" mcp install    （可选增强，零 key）
pause

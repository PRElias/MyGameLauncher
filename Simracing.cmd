@echo off
setlocal
chcp 65001 >nul

powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0Simracing.ps1"

if errorlevel 1 (
    echo.
    echo A execucao terminou com erro.
) else (
    echo.
    echo Execucao concluida.
)

pause
endlocal

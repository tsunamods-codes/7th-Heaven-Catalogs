@echo off
setlocal

cd /d "%~dp0"
if errorlevel 1 (
    echo Failed to open the repository directory.
    pause
    exit /b 1
)

powershell.exe -NoProfile -ExecutionPolicy Bypass -File ".github\workflows\validate.ps1"
set "result=%ERRORLEVEL%"

if not "%result%"=="0" echo Validation failed with exit code %result%.
pause
exit /b %result%

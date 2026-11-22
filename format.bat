@echo off
setlocal

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0.scripts\format.ps1" %*
set "result=%ERRORLEVEL%"

if not "%result%"=="0" echo Formatting failed or files need formatting. Exit code: %result%.
if "%~1"=="" pause
exit /b %result%

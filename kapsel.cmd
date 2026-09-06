:: Command Prompt and Explorer launcher for Kapsel.
@echo off
powershell.exe -NoProfile -STA -ExecutionPolicy Bypass -File "%~dp0kapsel.ps1" %*
set "kapselExitCode=%errorlevel%"
if errorlevel 1 pause
exit /b %kapselExitCode%

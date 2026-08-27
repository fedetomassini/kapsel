:: Command Prompt and Explorer launcher for Kapsel.
@echo off
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0kapsel.ps1" %*

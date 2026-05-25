:: This batch file serves as a wrapper to execute the Kapsel PowerShell script.
:: It ensures that the PowerShell script is run with the appropriate execution policy and without loading the user's profile, 
:: which can help avoid potential issues with conflicting settings or modules.

@echo off
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0kapsel.ps1" %*
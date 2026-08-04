# Requires -RunAsAdministrator
# This script serves as the entry point for the Kapsel application. 
# It forwards any provided arguments to the main script located in the 'src' directory. 
# If no arguments are provided, it simply runs the main script without any parameters.

param(
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]] $Arguments
)

function Get-KapselLauncherRoot {
    [CmdletBinding()]
    param()

    if (-not [string]::IsNullOrWhiteSpace($PSScriptRoot)) {
        return $PSScriptRoot
    }

    if (-not [string]::IsNullOrWhiteSpace($PSCommandPath)) {
        return Split-Path -Parent $PSCommandPath
    }

    $processPath = [System.Diagnostics.Process]::GetCurrentProcess().MainModule.FileName
    if (-not [string]::IsNullOrWhiteSpace($processPath)) {
        return Split-Path -Parent $processPath
    }

    return (Get-Location).Path
}

$launcherRoot = Get-KapselLauncherRoot
$entryPoint = Join-Path $launcherRoot 'src\Kapsel.ps1'

if (-not (Test-Path -LiteralPath $entryPoint)) {
    throw "Kapsel entry point was not found: $entryPoint"
}

if ($null -eq $Arguments -or $Arguments.Count -eq 0) {
    & $entryPoint
}
else {
    & $entryPoint @Arguments
}

exit $LASTEXITCODE

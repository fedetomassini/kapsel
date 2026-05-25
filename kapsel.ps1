# Requires -RunAsAdministrator
# This script serves as the entry point for the Kapsel application. 
# It forwards any provided arguments to the main script located in the 'src' directory. 
# If no arguments are provided, it simply runs the main script without any parameters.

param(
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]] $Arguments
)

$entryPoint = Join-Path $PSScriptRoot 'src\Kapsel.ps1'

if ($null -eq $Arguments -or $Arguments.Count -eq 0) {
    & $entryPoint
}
else {
    & $entryPoint @Arguments
}

exit $LASTEXITCODE

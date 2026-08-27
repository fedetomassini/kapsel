# Repository and packaged-executable launcher for Kapsel.
# The runtime root fallback keeps ps2exe builds independent from PowerShell's $PSScriptRoot behavior.

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

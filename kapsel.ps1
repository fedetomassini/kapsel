# Repository launcher for Kapsel. Kapsel runs from source; there is no executable build.

param(
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]] $Arguments
)

$launcherRoot = if (-not [string]::IsNullOrWhiteSpace($PSScriptRoot)) {
    $PSScriptRoot
}
elseif (-not [string]::IsNullOrWhiteSpace($PSCommandPath)) {
    Split-Path -Parent $PSCommandPath
}
else {
    (Get-Location).Path
}
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

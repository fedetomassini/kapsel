# Starts Kapsel from a stable repository-relative path for local development.
[CmdletBinding()]
param(
    [ValidateSet('ui', 'help', 'version')]
    [string] $Command = 'ui'
)

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$launcherPath = Join-Path $projectRoot 'kapsel.ps1'

if (-not (Test-Path -LiteralPath $launcherPath -PathType Leaf)) {
    throw "Kapsel launcher was not found: $launcherPath"
}

& $launcherPath $Command
exit $LASTEXITCODE

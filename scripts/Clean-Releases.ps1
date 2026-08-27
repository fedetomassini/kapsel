# Removes only generated release artifacts under this repository's dist directory.
[CmdletBinding(SupportsShouldProcess)]
param()

$ErrorActionPreference = 'Stop'
$projectRoot = [System.IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
$distRoot = [System.IO.Path]::GetFullPath((Join-Path $projectRoot 'dist'))
$releaseRoot = [System.IO.Path]::GetFullPath((Join-Path $distRoot 'releases'))
$expectedParent = [System.IO.Path]::GetFullPath((Split-Path -Parent $releaseRoot))

if (-not [string]::Equals($expectedParent.TrimEnd('\'), $distRoot.TrimEnd('\'), [System.StringComparison]::OrdinalIgnoreCase)) {
    throw "Refusing to clean an unexpected release path: $releaseRoot"
}

if (-not (Test-Path -LiteralPath $releaseRoot)) {
    Write-Host "Release directory is already clean: $releaseRoot"
    exit 0
}

if ($PSCmdlet.ShouldProcess($releaseRoot, 'Remove generated release artifacts')) {
    Remove-Item -LiteralPath $releaseRoot -Recurse -Force
}

if (Test-Path -LiteralPath $releaseRoot) {
    throw "Release directory could not be cleaned: $releaseRoot"
}

Write-Host "Release artifacts removed: $releaseRoot"

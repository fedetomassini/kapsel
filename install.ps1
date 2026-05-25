# Requires -RunAsAdministrator
# This script installs Kapsel launchers to a specified directory and optionally adds that directory to the user's PATH environment variable.
# Usage:
#  .\install.ps1 -InstallDirectory "C:\MyTools" -AddToUserPath

[CmdletBinding(SupportsShouldProcess)]
param(
    [string] $InstallDirectory = (Join-Path $HOME 'bin'),
    [switch] $AddToUserPath
)

$ErrorActionPreference = 'Stop'

$projectRoot = $PSScriptRoot
$entryPoint = Join-Path $projectRoot 'src\Kapsel.ps1'

if (-not (Test-Path -LiteralPath $entryPoint)) {
    throw "Kapsel entry point was not found: $entryPoint"
}

if ($PSCmdlet.ShouldProcess($InstallDirectory, 'Create Kapsel launchers')) {
    if (-not (Test-Path -LiteralPath $InstallDirectory)) {
        New-Item -ItemType Directory -Path $InstallDirectory -Force | Out-Null
    }

    $escapedEntryPoint = $entryPoint.Replace("'", "''")
    $psLauncherPath = Join-Path $InstallDirectory 'kapsel.ps1'
    $cmdLauncherPath = Join-Path $InstallDirectory 'kapsel.cmd'

    $psLauncher = @"
param(
    [Parameter(ValueFromRemainingArguments = `$true)]
    [string[]] `$Arguments
)

& '$escapedEntryPoint' @Arguments
exit `$LASTEXITCODE
"@

$cmdLauncher = @"
@echo off
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0kapsel.ps1" %*
"@

    Set-Content -LiteralPath $psLauncherPath -Value $psLauncher -Encoding UTF8
    Set-Content -LiteralPath $cmdLauncherPath -Value $cmdLauncher -Encoding ASCII
}

if ($AddToUserPath) {
    $currentPath = [Environment]::GetEnvironmentVariable('Path', 'User')
    $pathParts = @()

    if (-not [string]::IsNullOrWhiteSpace($currentPath)) {
        $pathParts = $currentPath -split ';' | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
    }

    $alreadyConfigured = $pathParts | Where-Object { $_.TrimEnd('\') -ieq $InstallDirectory.TrimEnd('\') }

    if (-not $alreadyConfigured) {
        $newPath = (@($pathParts) + $InstallDirectory) -join ';'
        [Environment]::SetEnvironmentVariable('Path', $newPath, 'User')
        Write-Host 'User PATH updated. Open a new terminal before running kapsel.'
    }
}

Write-Host ("Kapsel launchers installed in: {0}" -f (Resolve-Path -LiteralPath $InstallDirectory).Path)

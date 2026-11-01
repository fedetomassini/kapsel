# Verifies a built release ZIP from the outside: checksum, contents, launcher and bundled docs.
[CmdletBinding()]
param(
    [string] $ArchivePath,
    [string] $Version,
    [switch] $KeepExtracted
)

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
if ([string]::IsNullOrWhiteSpace($Version)) {
    $Version = (Get-Content -LiteralPath (Join-Path $projectRoot 'package.json') -Raw | ConvertFrom-Json).version
}
if ([string]::IsNullOrWhiteSpace($ArchivePath)) {
    $ArchivePath = Join-Path $projectRoot "dist\releases\Kapsel-$Version-windows.zip"
}
if (-not (Test-Path -LiteralPath $ArchivePath -PathType Leaf)) {
    throw "Release archive not found: $ArchivePath"
}

function Get-KapselArchiveSha256 {
    param([Parameter(Mandatory = $true)] [string] $Path)

    $stream = [System.IO.File]::OpenRead($Path)
    try {
        $algorithm = [System.Security.Cryptography.SHA256]::Create()
        try {
            return ([BitConverter]::ToString($algorithm.ComputeHash($stream)) -replace '-', '').ToLowerInvariant()
        }
        finally { $algorithm.Dispose() }
    }
    finally { $stream.Dispose() }
}

$checksumPath = "$ArchivePath.sha256"
if (-not (Test-Path -LiteralPath $checksumPath -PathType Leaf)) {
    throw "Release checksum not found: $checksumPath"
}
$recorded = ((Get-Content -LiteralPath $checksumPath -Raw).Trim() -split '\s+')[0]
$actual = Get-KapselArchiveSha256 -Path $ArchivePath
if ($recorded -ne $actual) {
    throw "Release checksum does not match the archive: $ArchivePath"
}

Add-Type -AssemblyName System.IO.Compression.FileSystem
$extractRoot = Join-Path ([System.IO.Path]::GetTempPath()) "Kapsel release check $([guid]::NewGuid().ToString('N'))"
[void] (New-Item -ItemType Directory -Path $extractRoot -Force)
try {
    [System.IO.Compression.ZipFile]::ExtractToDirectory($ArchivePath, $extractRoot)

    $required = @(
        'kapsel.cmd', 'kapsel.ps1', 'install.ps1',
        'src\applications.json', 'src\Kapsel.ps1', 'src\modules\Shared\ProductMetadata.psm1',
        'assets\logo.png', 'assets\fonts\fa-solid-900.ttf', 'assets\fonts\LICENSE-Font-Awesome.txt',
        'README.md', 'CATALOG.md', 'CHANGELOG.md', 'CONTRIBUTING.md', 'SUPPORT.md', 'SECURITY.md',
        'CODE_OF_CONDUCT.md', 'LICENSE', 'package.json', '.node-version',
        'docs\README.md', 'docs\USER_GUIDE.md', 'docs\CONFIGURATION.md', 'docs\TROUBLESHOOTING.md',
        '.github\assets\kapsel.png'
    )
    foreach ($relative in $required) {
        $path = Join-Path $extractRoot $relative
        if (-not (Test-Path -LiteralPath $path)) {
            throw "Release archive is missing: $relative"
        }
    }
    foreach ($forbidden in @('ROADMAP.md', 'AGENTS.md')) {
        if (Test-Path -LiteralPath (Join-Path $extractRoot $forbidden)) {
            throw "Release archive must not contain local guidance: $forbidden"
        }
    }

    $dataDirectory = Join-Path $extractRoot 'isolated data'
    $previousDataDirectory = $env:KAPSEL_DATA_DIRECTORY
    try {
        $env:KAPSEL_DATA_DIRECTORY = $dataDirectory
        $versionOutput = & powershell.exe -NoProfile -STA -ExecutionPolicy Bypass -File (Join-Path $extractRoot 'kapsel.ps1') version 2>&1
        if ($LASTEXITCODE -ne 0) { throw "Extracted launcher failed with exit code $LASTEXITCODE." }
        if (-not (@($versionOutput) | Where-Object { $_ -match "^Kapsel $([regex]::Escape($Version))$" })) {
            throw "Extracted launcher did not report Kapsel $Version. Output: $($versionOutput -join ' | ')"
        }
        $helpOutput = & powershell.exe -NoProfile -STA -ExecutionPolicy Bypass -File (Join-Path $extractRoot 'kapsel.ps1') help 2>&1
        if ($LASTEXITCODE -ne 0) { throw "Extracted help command failed with exit code $LASTEXITCODE." }
        if (-not (@($helpOutput) | Where-Object { $_ -match 'Usage:' })) {
            throw 'Extracted launcher did not print help usage.'
        }
        if (Test-Path -LiteralPath (Join-Path $dataDirectory 'preferences.json')) {
            throw 'The version/help commands must not write user preferences.'
        }
    }
    finally {
        $env:KAPSEL_DATA_DIRECTORY = $previousDataDirectory
    }

    Write-Host "Release package OK: Kapsel $Version from $extractRoot"
    Write-Host "Verified SHA-256 $actual and $($required.Count) required files."
}
finally {
    if (-not $KeepExtracted) {
        Remove-Item -LiteralPath $extractRoot -Recurse -Force -ErrorAction SilentlyContinue
    }
}

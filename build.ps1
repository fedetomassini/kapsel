# Builds a distributable Kapsel package for GitHub Releases.
[CmdletBinding()]
param(
    [string] $OutputDirectory,
    [switch] $InstallBuildDependency,
    [switch] $SkipExecutable,
    [switch] $IncludeExecutable
)

$ErrorActionPreference = 'Stop'
if ($SkipExecutable -and $IncludeExecutable) { throw 'Choose either SkipExecutable or IncludeExecutable.' }

$projectRoot = $PSScriptRoot
if ([string]::IsNullOrWhiteSpace($OutputDirectory)) {
    $OutputDirectory = Join-Path $projectRoot 'dist'
}
$OutputDirectory = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($OutputDirectory)

$launcherPath = Join-Path $projectRoot 'kapsel.ps1'
$sourcePath = Join-Path $projectRoot 'src'
$assetsPath = Join-Path $projectRoot 'assets'
$metadataModule = Join-Path $sourcePath 'modules\Shared\ProductMetadata.psm1'

if (-not (Test-Path -LiteralPath $launcherPath)) {
    throw "Launcher not found: $launcherPath"
}

if (-not (Test-Path -LiteralPath $sourcePath)) {
    throw "Source directory not found: $sourcePath"
}

if (-not (Test-Path -LiteralPath $metadataModule)) {
    throw "Metadata module not found: $metadataModule"
}

Import-Module $metadataModule -Force
$metadata = Get-KapselProductMetadata
$version = [string] $metadata.Version
$packageName = '{0}-{1}-windows' -f $metadata.Name, $version
$releaseRoot = Join-Path (Join-Path $OutputDirectory 'releases') $packageName
$zipPath = Join-Path (Join-Path $OutputDirectory 'releases') "$packageName.zip"
$executablePath = Join-Path $releaseRoot "$($metadata.Name).exe"

function ConvertTo-KapselIconFile {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string] $ImagePath,

        [Parameter(Mandatory = $true)]
        [string] $IconPath
    )

    $image = $null
    $stream = $null
    $writer = $null

    try {
        Add-Type -AssemblyName System.Drawing
        $image = [System.Drawing.Image]::FromFile($ImagePath)
        $imageBytes = [System.IO.File]::ReadAllBytes($ImagePath)
        $width = if ($image.Width -ge 256) { 0 } else { [byte] $image.Width }
        $height = if ($image.Height -ge 256) { 0 } else { [byte] $image.Height }

        $stream = [System.IO.File]::Open($IconPath, [System.IO.FileMode]::Create, [System.IO.FileAccess]::Write)
        $writer = New-Object System.IO.BinaryWriter($stream)

        $writer.Write([UInt16] 0)
        $writer.Write([UInt16] 1)
        $writer.Write([UInt16] 1)
        $writer.Write([byte] $width)
        $writer.Write([byte] $height)
        $writer.Write([byte] 0)
        $writer.Write([byte] 0)
        $writer.Write([UInt16] 1)
        $writer.Write([UInt16] 32)
        $writer.Write([UInt32] $imageBytes.Length)
        $writer.Write([UInt32] 22)
        $writer.Write($imageBytes)
    }
    finally {
        if ($null -ne $writer) { $writer.Dispose() }
        if ($null -ne $stream) { $stream.Dispose() }
        if ($null -ne $image) { $image.Dispose() }
    }
}

function Copy-KapselDirectory {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string] $Source,

        [Parameter(Mandatory = $true)]
        [string] $Destination
    )

    if (Test-Path -LiteralPath $Destination) {
        Remove-Item -LiteralPath $Destination -Recurse -Force
    }

    Copy-Item -LiteralPath $Source -Destination $Destination -Recurse -Force
}

if (Test-Path -LiteralPath $releaseRoot) {
    Remove-Item -LiteralPath $releaseRoot -Recurse -Force
}

if (Test-Path -LiteralPath $zipPath) {
    Remove-Item -LiteralPath $zipPath -Force
}

New-Item -ItemType Directory -Path $releaseRoot -Force | Out-Null

Copy-KapselDirectory -Source $sourcePath -Destination (Join-Path $releaseRoot 'src')
if (Test-Path -LiteralPath $assetsPath) {
    Copy-KapselDirectory -Source $assetsPath -Destination (Join-Path $releaseRoot 'assets')
}

Copy-Item -LiteralPath $launcherPath -Destination (Join-Path $releaseRoot 'kapsel.ps1') -Force
Copy-Item -LiteralPath (Join-Path $projectRoot 'kapsel.cmd') -Destination (Join-Path $releaseRoot 'kapsel.cmd') -Force
Copy-Item -LiteralPath (Join-Path $projectRoot 'install.ps1') -Destination (Join-Path $releaseRoot 'install.ps1') -Force

foreach ($document in @(
    'README.md', 'CATALOG.md', 'CHANGELOG.md', 'CONTRIBUTING.md',
    'SUPPORT.md', 'CODE_OF_CONDUCT.md', 'LICENSE', 'package.json', '.node-version'
)) {
    Copy-Item -LiteralPath (Join-Path $projectRoot $document) -Destination (Join-Path $releaseRoot $document) -Force
}
Copy-KapselDirectory -Source (Join-Path $projectRoot 'docs') -Destination (Join-Path $releaseRoot 'docs')
# The README image must keep the same relative path in a checkout and an extracted release.
$documentationAssets = Join-Path $releaseRoot '.github\assets'
New-Item -ItemType Directory -Path $documentationAssets -Force | Out-Null
Copy-Item -LiteralPath (Join-Path $projectRoot '.github\assets\kapsel.png') -Destination $documentationAssets -Force

& node (Join-Path $projectRoot 'scripts\Validate-Documentation.mjs') --root $releaseRoot
if ($LASTEXITCODE -ne 0) { throw 'Packaged documentation validation failed.' }

if ($IncludeExecutable) {
    $ps2exeCommand = Get-Command Invoke-ps2exe -ErrorAction SilentlyContinue
    if ($null -eq $ps2exeCommand -and $InstallBuildDependency) {
        Install-Module -Name ps2exe -Scope CurrentUser -Force -AllowClobber
        Import-Module ps2exe -Force
        $ps2exeCommand = Get-Command Invoke-ps2exe -ErrorAction SilentlyContinue
    }

    if ($null -eq $ps2exeCommand) {
        throw 'Invoke-ps2exe was not found. Install ps2exe or run .\build.ps1 -IncludeExecutable -InstallBuildDependency.'
    }

    $buildTemp = Join-Path $OutputDirectory 'temp'
    New-Item -ItemType Directory -Path $buildTemp -Force | Out-Null
    $iconPath = $null
    $logoPath = Join-Path $assetsPath 'logo.png'

    if (Test-Path -LiteralPath $logoPath) {
        $iconPath = Join-Path $buildTemp 'kapsel.ico'
        ConvertTo-KapselIconFile -ImagePath $logoPath -IconPath $iconPath
    }

    $ps2exeArgs = @{
        inputFile   = $launcherPath
        outputFile  = $executablePath
        noConsole   = $true
        STA         = $true
        title       = $metadata.Name
        description = $metadata.Description
        product     = $metadata.Name
        company     = $metadata.Creator
        copyright   = "Copyright (c) $((Get-Date).Year) $($metadata.Creator)"
        version     = $version
    }

    if (-not [string]::IsNullOrWhiteSpace($iconPath)) {
        $ps2exeArgs.iconFile = $iconPath
    }

    Invoke-ps2exe @ps2exeArgs
}

$releaseItems = @(Get-ChildItem -LiteralPath $releaseRoot -Force)
if ($releaseItems.Count -eq 0) {
    throw "Release directory is empty: $releaseRoot"
}

$releaseItems | Compress-Archive -DestinationPath $zipPath -Force

if (-not (Test-Path -LiteralPath $zipPath)) {
    throw "Release archive was not created: $zipPath"
}

# Compare the archive to the staged tree so missing docs/assets fail before publication.
Add-Type -AssemblyName System.IO.Compression.FileSystem
$archive = [System.IO.Compression.ZipFile]::OpenRead($zipPath)
try {
    $entries = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::OrdinalIgnoreCase)
    foreach ($entry in $archive.Entries) { [void] $entries.Add($entry.FullName.Replace('\', '/')) }
    foreach ($file in @(Get-ChildItem -LiteralPath $releaseRoot -File -Recurse -Force)) {
        $relativePath = $file.FullName.Substring($releaseRoot.TrimEnd('\', '/').Length + 1).Replace('\', '/')
        if (-not $entries.Contains($relativePath)) { throw "Release archive is missing: $relativePath" }
    }
}
finally {
    $archive.Dispose()
}

Write-Host "Release package: $releaseRoot"
Write-Host "Release archive: $zipPath"

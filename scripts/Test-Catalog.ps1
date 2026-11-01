# Lints the curated application catalog before packaging.
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$catalogPath = Join-Path $projectRoot 'src\applications.json'
$allowedCategories = @(
    'Browsers', 'Communications', 'Development', 'Games', 'Microsoft Tools',
    'Multimedia Tools', 'Pro Tools', 'Selfhosted Tools', 'Utilities'
)

if (-not (Test-Path -LiteralPath $catalogPath -PathType Leaf)) {
    throw "Catalog not found: $catalogPath"
}

$failures = New-Object System.Collections.Generic.List[string]
$raw = Get-Content -LiteralPath $catalogPath -Raw
$document = $null
try {
    $document = $raw | ConvertFrom-Json -ErrorAction Stop
}
catch {
    throw "Catalog is not valid JSON: $($_.Exception.Message)"
}
if ($null -eq $document -or $document -isnot [PSCustomObject]) {
    throw 'Catalog must be a JSON object keyed by stable application keys.'
}

# ConvertFrom-Json collapses duplicate property names, so detect them in the source text.
$keyPattern = [regex]::new('(?m)^\t"([^"]+)"\s*:\s*\{')
$seenKeys = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase)
foreach ($match in $keyPattern.Matches($raw)) {
    $key = $match.Groups[1].Value
    if (-not $seenKeys.Add($key)) {
        [void] $failures.Add("Duplicate catalog key: $key")
    }
}

Import-Module (Join-Path $projectRoot 'src\modules\Domain\ApplicationCatalog.psm1') -Force
$applications = @()
try {
    $applications = @(ConvertFrom-KapselCatalogDocument -CatalogDocument $document)
}
catch {
    [void] $failures.Add($_.Exception.Message)
}

$entries = @($document.PSObject.Properties)
foreach ($entry in $entries) {
    $key = [string] $entry.Name
    $value = $entry.Value
    foreach ($field in @('category', 'content', 'description', 'link', 'foss')) {
        if ($null -eq $value.PSObject.Properties[$field]) {
            [void] $failures.Add("Catalog entry '$key' is missing '$field'.")
        }
    }
    if ($null -eq $value.PSObject.Properties['winget'] -and $null -eq $value.PSObject.Properties['choco']) {
        [void] $failures.Add("Catalog entry '$key' has no winget or choco identifier.")
    }
    $category = [string] $value.category
    if ($category -and $category -notin $allowedCategories) {
        [void] $failures.Add("Catalog entry '$key' uses unknown category '$category'.")
    }
    $link = [string] $value.link
    if ($link -and $link -notmatch '^https://') {
        [void] $failures.Add("Catalog entry '$key' should use an https official link: $link")
    }
}

$warnings = New-Object System.Collections.Generic.List[string]
foreach ($provider in @('WingetId', 'ChocoId')) {
    $duplicates = @($applications | Where-Object { $_.$provider } | Group-Object -Property $provider | Where-Object { $_.Count -gt 1 })
    foreach ($duplicate in $duplicates) {
        $names = @($duplicate.Group | ForEach-Object { $_.Key } | Sort-Object)
        [void] $warnings.Add("Duplicate $provider '$($duplicate.Name)' is shared by alias keys: $($names -join ', ')")
    }
}

if ($warnings.Count -gt 0) {
    $warnings | ForEach-Object { Write-Warning $_ }
}

if ($failures.Count -gt 0) {
    $failures | ForEach-Object { Write-Error $_ }
    exit 1
}

Write-Host "Catalog lint OK: $($applications.Count) applications, $($allowedCategories.Count) categories, $($warnings.Count) alias warning(s)."

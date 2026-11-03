# Read-only catalog health audit: official links and winget/Chocolatey identifiers.
[CmdletBinding()]
param(
    [ValidateRange(1, 120)] [int] $TimeoutSeconds = 15,
    [ValidateRange(1, 32)] [int] $MaxConcurrency = 8,
    [switch] $SkipLinks,
    [switch] $SkipWinget,
    [switch] $SkipChoco,
    [string] $OutputPath,
    [switch] $FailOnBroken
)

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
Import-Module (Join-Path $projectRoot 'src\modules\Application\CatalogService.psm1') -Force
Import-Module (Join-Path $projectRoot 'src\modules\Infrastructure\JsonCatalogRepository.psm1') -Force
Import-Module (Join-Path $projectRoot 'src\modules\Infrastructure\CatalogHealth.psm1') -Force

function Get-KapselFileSha256 {
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

$catalogPath = Get-KapselApplicationCatalogPath
$document = Read-KapselApplicationCatalogDocument -Path $catalogPath
$snapshot = New-KapselCatalogSnapshot -CatalogDocument $document
$applications = @($snapshot.Applications)
$catalogSha256 = Get-KapselFileSha256 -Path $catalogPath

Write-Host "Checking $($applications.Count) catalog entries (timeout ${TimeoutSeconds}s, concurrency $MaxConcurrency)."
$linkResults = if ($SkipLinks) { @{} } else { Invoke-KapselCatalogLinkCheck -Applications $applications -TimeoutSeconds $TimeoutSeconds -MaxConcurrency $MaxConcurrency }
$wingetResults = if ($SkipWinget) { @{} } else { Invoke-KapselWingetIdCheck -Applications $applications -TimeoutSeconds $TimeoutSeconds -MaxConcurrency $MaxConcurrency }
$chocoResults = if ($SkipChoco) { @{} } else { Invoke-KapselChocoIdCheck -Applications $applications -TimeoutSeconds $TimeoutSeconds -MaxConcurrency $MaxConcurrency }

$report = New-KapselCatalogHealthReport -Applications $applications -LinkResults $linkResults -WingetResults $wingetResults -ChocoResults $chocoResults -CatalogPath $catalogPath -CatalogSha256 $catalogSha256
$json = $report | ConvertTo-Json -Depth 6

if (-not [string]::IsNullOrWhiteSpace($OutputPath)) {
    $path = if ([System.IO.Path]::IsPathRooted($OutputPath)) { $OutputPath } else { Join-Path $projectRoot $OutputPath }
    [void] (New-Item -ItemType Directory -Path (Split-Path -Parent $path) -Force)
    [System.IO.File]::WriteAllText($path, $json, (New-Object System.Text.UTF8Encoding($false)))
    Write-Host "Report: $path"
}

Write-Host "Links: $($report.Links.Ok) ok, $($report.Links.Broken) broken, $($report.Links.Inconclusive) inconclusive."
Write-Host "winget IDs: $($report.WingetIds.Ok) ok, $($report.WingetIds.Broken) broken, $($report.WingetIds.Inconclusive) inconclusive."
Write-Host "Chocolatey IDs: $($report.ChocoIds.Ok) ok, $($report.ChocoIds.Broken) broken, $($report.ChocoIds.Inconclusive) inconclusive."

$broken = @($report.Entries | Where-Object {
    $_.LinkOutcome -eq 'Broken' -or $_.WingetOutcome -eq 'Broken' -or $_.ChocoOutcome -eq 'Broken'
})
foreach ($entry in $broken) {
    $details = @()
    if ($entry.LinkOutcome -eq 'Broken') { $details += "link $($entry.LinkStatusCode) $($entry.Link)" }
    if ($entry.WingetOutcome -eq 'Broken') { $details += "winget $($entry.WingetStatusCode) $($entry.WingetId)" }
    if ($entry.ChocoOutcome -eq 'Broken') { $details += "choco $($entry.ChocoStatusCode) $($entry.ChocoId)" }
    Write-Host "Broken: $($entry.Key) ($($entry.Name)): $($details -join '; ')"
}

if ($FailOnBroken -and $broken.Count -gt 0) { exit 1 }

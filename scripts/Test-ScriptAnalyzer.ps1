# Incremental PSScriptAnalyzer gate. Existing findings are baselined by rule, file and message.
[CmdletBinding()]
param(
    [switch] $RequireModule,
    [string] $BaselinePath
)

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
if ([string]::IsNullOrWhiteSpace($BaselinePath)) {
    $BaselinePath = Join-Path $projectRoot '.psscriptanalyzer-baseline.json'
}
$module = Get-Module -ListAvailable PSScriptAnalyzer | Sort-Object Version -Descending | Select-Object -First 1
if ($null -eq $module) {
    if ($RequireModule) {
        throw 'PSScriptAnalyzer is required for this run. Install-Module PSScriptAnalyzer -Scope CurrentUser -Force.'
    }
    Write-Host 'PSScriptAnalyzer is not installed; static analysis skipped.'
    return
}

Import-Module $module.Path -Force
$settingsPath = Join-Path $projectRoot '.psscriptanalyzer.settings.psd1'
if (-not (Test-Path -LiteralPath $settingsPath)) { throw "PSScriptAnalyzer settings not found: $settingsPath" }

$results = @()
foreach ($target in @('src', 'scripts', 'build.ps1', 'kapsel.ps1', 'install.ps1')) {
    $path = Join-Path $projectRoot $target
    if (-not (Test-Path -LiteralPath $path)) { continue }
    Write-Verbose "Analyzing $path"
    $results += @(Invoke-ScriptAnalyzer -Path $path -Recurse -Settings $settingsPath -ErrorAction Stop)
}

$baselineKeys = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::Ordinal)
if (Test-Path -LiteralPath $BaselinePath -PathType Leaf) {
    foreach ($item in @(Get-Content -LiteralPath $BaselinePath -Raw | ConvertFrom-Json)) {
        if ($null -eq $item) { continue }
        [void] $baselineKeys.Add(('{0}|{1}|{2}' -f $item.RuleName, $item.ScriptName, $item.Message))
    }
}

$newFindings = @($results | Where-Object {
    -not $baselineKeys.Contains(('{0}|{1}|{2}' -f $_.RuleName, $_.ScriptName, $_.Message))
})

if ($newFindings.Count -gt 0) {
    foreach ($finding in $newFindings) {
        Write-Error ('{0}:{1} [{2}] {3}' -f $finding.ScriptName, $finding.Line, $finding.RuleName, $finding.Message)
    }
    Write-Host "PSScriptAnalyzer found $($newFindings.Count) new finding(s). Fix them or update the baseline intentionally."
    exit 1
}

Write-Host "PSScriptAnalyzer OK: $($results.Count) finding(s), all baselined."

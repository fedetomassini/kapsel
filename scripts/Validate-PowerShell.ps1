# Validates PowerShell source syntax without executing application code.
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$files = Get-ChildItem -Path $projectRoot -Recurse -Include *.ps1,*.psm1 |
    Where-Object { $_.FullName -notlike '*\dist\*' }

$failures = New-Object System.Collections.Generic.List[string]

foreach ($file in $files) {
    $tokens = $null
    $errors = $null
    [System.Management.Automation.Language.Parser]::ParseFile($file.FullName, [ref] $tokens, [ref] $errors) | Out-Null

    foreach ($errorRecord in @($errors)) {
        [void] $failures.Add(('{0}: {1}' -f $file.FullName, $errorRecord.Message))
    }
}

if ($failures.Count -gt 0) {
    $failures | ForEach-Object { Write-Error $_ }
    exit 1
}

Write-Host 'PowerShell syntax OK'

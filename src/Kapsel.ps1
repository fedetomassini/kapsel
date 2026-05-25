[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [string] $Command = 'ui'
)

$ErrorActionPreference = 'Stop'

$moduleRoot = Join-Path $PSScriptRoot 'modules'
Import-Module (Join-Path $moduleRoot 'Branding.psm1') -Force
$metadata = Get-KapselMetadata

function Show-KapselHelp {
    @'
Kapsel - Windows application installer

Usage:
  kapsel
  kapsel ui
  kapsel help
  kapsel version

Kapsel reads src/applications.json and lets you install or update selected applications with winget or Chocolatey.
'@ | Write-Host
}

try {
    if ([string]::IsNullOrWhiteSpace($Command)) {
        $Command = 'ui'
    }

    switch ($Command.ToLowerInvariant()) {
        { $_ -in @('ui', 'app', 'apps') } {
            Import-Module (Join-Path $moduleRoot 'Gui.psm1') -Force
            Gui\Show-KapselGui
        }
        { $_ -in @('help', '--help', '-h') } {
            Show-KapselHelp
        }
        'version' {
            Write-Host "$($metadata.Name) $($metadata.Version)"
            Write-Host "Creator: $($metadata.Creator)"
        }
        default {
            throw ("Unknown command: {0}" -f $Command)
        }
    }

    exit 0
}
catch {
    Write-Error $_.Exception.Message
    Write-Host ''
    Show-KapselHelp
    exit 1
}

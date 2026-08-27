# JSON catalog adapter. It owns filesystem access and JSON parsing.
Set-StrictMode -Version Latest

function Get-KapselApplicationCatalogPath {
    [CmdletBinding()]
    param()

    $sourceRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
    return Join-Path $sourceRoot 'applications.json'
}

function Read-KapselApplicationCatalogDocument {
    [CmdletBinding()]
    param(
        [string] $Path = (Get-KapselApplicationCatalogPath)
    )

    if ([string]::IsNullOrWhiteSpace($Path)) {
        throw 'The application catalog path cannot be empty.'
    }
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        throw "Application catalog not found: $Path"
    }

    try {
        return Get-Content -LiteralPath $Path -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
    }
    catch {
        throw "Application catalog could not be read from '$Path': $($_.Exception.Message)"
    }
}

Export-ModuleMember -Function @(
    'Get-KapselApplicationCatalogPath',
    'Read-KapselApplicationCatalogDocument'
)

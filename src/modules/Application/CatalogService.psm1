# Catalog use cases exposed to presentation and entry points.
Set-StrictMode -Version Latest

Import-Module (Join-Path (Split-Path -Parent $PSScriptRoot) 'Domain\ApplicationCatalog.psm1') -Force

function New-KapselCatalogSnapshot {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [object] $CatalogDocument
    )

    $applications = @(ConvertFrom-KapselCatalogDocument -CatalogDocument $CatalogDocument)
    $categories = @(Get-KapselApplicationCategories -Applications $applications)

    return [PSCustomObject] @{
        Applications = $applications
        Categories   = $categories
        Counts       = [PSCustomObject] @{
            Applications = $applications.Count
            Categories   = @($categories | Where-Object { $_ -ne 'All' }).Count
            Foss         = @($applications | Where-Object { $_.Foss }).Count
            Winget       = @($applications | Where-Object { $_.WingetId }).Count
            Choco        = @($applications | Where-Object { $_.ChocoId }).Count
        }
    }
}

function Find-KapselApplications {
    [CmdletBinding()]
    param(
        [object[]] $Applications = @(),
        [string] $Search,
        [string] $Category = 'All',
        [switch] $FossOnly
    )

    return @(Search-KapselApplicationCatalog @PSBoundParameters)
}

function Get-KapselDefaultCategory {
    [CmdletBinding()]
    param([string[]] $Categories = @())

    $visible = @($Categories | Where-Object { $_ -ne 'All' })
    if ($visible -contains 'Browsers') {
        return 'Browsers'
    }
    if ($visible.Count -gt 0) {
        return $visible[0]
    }
    return 'All'
}

function Test-KapselProviderCompatibility {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)] [object] $Application,
        [Parameter(Mandatory = $true)]
        [ValidateSet('winget', 'choco')]
        [string] $Provider
    )

    return Test-KapselApplicationProviderSupport -Application $Application -Provider $Provider
}

Export-ModuleMember -Function @(
    'New-KapselCatalogSnapshot',
    'Find-KapselApplications',
    'Get-KapselDefaultCategory',
    'Test-KapselProviderCompatibility'
)

# Maps provider inventory to the curated application catalog.
Set-StrictMode -Version Latest

Import-Module (Join-Path (Split-Path -Parent $PSScriptRoot) 'Domain\PackageInventory.psm1') -Force

function Get-KapselCatalogInventory {
    [CmdletBinding()]
    param(
        [object[]] $Applications = @(),
        [Parameter(Mandatory = $true)] [ValidateSet('winget', 'choco')] [string] $Provider,
        [Parameter(Mandatory = $true)] [object] $ProviderInventory
    )

    $installed = if ($Provider -eq 'winget') {
        ConvertFrom-KapselWingetExport -Document $ProviderInventory.InstalledDocument
    }
    else {
        ConvertFrom-KapselChocolateyList -Output $ProviderInventory.InstalledOutput
    }
    $updates = if ($Provider -eq 'winget') {
        Get-KapselWingetUpdateIds -Output $ProviderInventory.UpdateOutput -KnownIds @($Applications | ForEach-Object { $_.WingetId })
    }
    else {
        ConvertFrom-KapselChocolateyList -Output $ProviderInventory.UpdateOutput
    }
    return New-KapselInventorySnapshot -Applications $Applications -Provider $Provider -Installed $installed -Updates $updates -UpdatesChecked ([bool] $ProviderInventory.UpdatesChecked)
}

function Find-KapselInventoryApplications {
    [CmdletBinding()]
    param(
        [object[]] $Applications = @(),
        [AllowNull()] [object] $Snapshot,
        [Parameter(Mandatory = $true)] [ValidateSet('All', 'Installed', 'Updates')] [string] $Filter
    )

    if ($Filter -eq 'All') { return @($Applications) }
    if ($null -eq $Snapshot) { return @() }
    return @($Applications | Where-Object {
        $state = $Snapshot.States[[string] $_.Key]
        if ($null -eq $state) { return $false }
        if ($Filter -eq 'Updates') { return $state.Status -eq 'UpdateAvailable' }
        return $state.Status -in @('Installed', 'UpdateAvailable')
    })
}

Export-ModuleMember -Function @('Get-KapselCatalogInventory', 'Find-KapselInventoryApplications')

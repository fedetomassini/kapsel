# Pure parsing and catalog matching for provider-owned package inventory.
Set-StrictMode -Version Latest

function ConvertFrom-KapselWingetExport {
    [CmdletBinding()]
    param([Parameter(Mandatory = $true)] [object] $Document)

    if ($null -eq $Document.PSObject.Properties['Sources']) {
        throw 'winget export did not contain Sources.'
    }
    $packages = @{}
    foreach ($source in @($Document.Sources)) {
        if ($null -eq $source -or $null -eq $source.Packages) { continue }
        foreach ($package in @($source.Packages)) {
            $id = [string] $package.PackageIdentifier
            if ([string]::IsNullOrWhiteSpace($id)) { continue }
            $packages[$id] = [string] $package.Version
        }
    }
    return $packages
}

function ConvertFrom-KapselChocolateyList {
    [CmdletBinding()]
    param([AllowEmptyString()] [string] $Output)

    $packages = @{}
    foreach ($line in ($Output -split '\r?\n')) {
        if ($line -notmatch '^([A-Za-z0-9][A-Za-z0-9._+\-]*)\|([^|\r\n]+)') { continue }
        $packages[$matches[1]] = $matches[2].Trim()
    }
    return $packages
}

function Get-KapselWingetUpdateIds {
    [CmdletBinding()]
    param(
        [AllowEmptyString()] [string] $Output,
        [string[]] $KnownIds = @()
    )

    $updates = @{}
    foreach ($id in $KnownIds) {
        if ([string]::IsNullOrWhiteSpace($id)) { continue }
        $pattern = '(?<![A-Za-z0-9._+\-])' + [regex]::Escape($id) + '(?![A-Za-z0-9._+\-])'
        foreach ($line in ($Output -split '\r?\n')) {
            if ($line -match $pattern) {
                $updates[$id] = $true
                break
            }
        }
    }
    return $updates
}

function New-KapselInventorySnapshot {
    [CmdletBinding()]
    param(
        [object[]] $Applications = @(),
        [Parameter(Mandatory = $true)] [ValidateSet('winget', 'choco')] [string] $Provider,
        [Parameter(Mandatory = $true)] [hashtable] $Installed,
        [Parameter(Mandatory = $true)] [hashtable] $Updates,
        [bool] $UpdatesChecked = $true
    )

    $states = @{}
    foreach ($application in $Applications) {
        $id = if ($Provider -eq 'winget') { [string] $application.WingetId } else { [string] $application.ChocoId }
        $status = if ([string]::IsNullOrWhiteSpace($id)) { 'Unsupported' }
        elseif (-not $Installed.ContainsKey($id)) { 'NotDetected' }
        elseif ($Updates.ContainsKey($id)) { 'UpdateAvailable' }
        elseif (-not $UpdatesChecked) { 'Installed' }
        else { 'Installed' }
        $states[[string] $application.Key] = [PSCustomObject] @{
            Status = $status
            Version = if ($Installed.ContainsKey($id)) { [string] $Installed[$id] } else { '' }
            UpdateCheckSucceeded = $UpdatesChecked
        }
    }
    return [PSCustomObject] @{
        Provider = $Provider
        States = $states
        InstalledCount = @($states.Values | Where-Object { $_.Status -in @('Installed', 'UpdateAvailable') }).Count
        UpdateCount = @($states.Values | Where-Object { $_.Status -eq 'UpdateAvailable' }).Count
        UpdatesChecked = $UpdatesChecked
    }
}

Export-ModuleMember -Function @(
    'ConvertFrom-KapselWingetExport',
    'ConvertFrom-KapselChocolateyList',
    'Get-KapselWingetUpdateIds',
    'New-KapselInventorySnapshot'
)

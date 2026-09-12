$ProjectRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
Import-Module (Join-Path $ProjectRoot 'src\modules\Application\InventoryService.psm1') -Force
Import-Module (Join-Path $ProjectRoot 'src\modules\Domain\PackageInventory.psm1') -Force

Describe 'Package inventory matching' {
    $applications = @(
        [PSCustomObject] @{ Key = 'firefox'; WingetId = 'Mozilla.Firefox'; ChocoId = 'firefox' },
        [PSCustomObject] @{ Key = 'zed'; WingetId = 'ZedIndustries.Zed'; ChocoId = $null },
        [PSCustomObject] @{ Key = 'other'; WingetId = 'Publisher.Other'; ChocoId = 'other' }
    )

    It 'reads winget export JSON by exact package identifier' {
        $document = [PSCustomObject] @{ Sources = @([PSCustomObject] @{ Packages = @(
            [PSCustomObject] @{ PackageIdentifier = 'Mozilla.Firefox'; Version = '130.0' },
            [PSCustomObject] @{ PackageIdentifier = 'ZedIndustries.Zed'; Version = '0.2' }
        ) }) }
        $provider = [PSCustomObject] @{
            InstalledDocument = $document
            UpdateOutput = 'Firefox  Mozilla.Firefox  130.0  131.0  winget'
            UpdatesChecked = $true
        }

        $snapshot = Get-KapselCatalogInventory -Applications $applications -Provider winget -ProviderInventory $provider

        $snapshot.States.firefox.Status | Should Be 'UpdateAvailable'
        $snapshot.States.firefox.Version | Should Be '130.0'
        $snapshot.States.zed.Status | Should Be 'Installed'
        $snapshot.States.other.Status | Should Be 'NotDetected'
        $snapshot.InstalledCount | Should Be 2
        $snapshot.UpdateCount | Should Be 1
    }

    It 'does not match a winget identifier prefix as an update' {
        $updates = Get-KapselWingetUpdateIds -Output 'Firefox ESR  Mozilla.Firefox.ESR  1  2  winget' -KnownIds @('Mozilla.Firefox')
        $updates.ContainsKey('Mozilla.Firefox') | Should Be $false
    }

    It 'parses Chocolatey limited output without treating summaries as packages' {
        $provider = [PSCustomObject] @{
            InstalledOutput = "firefox|130.0`nother|2.0`n2 packages installed."
            UpdateOutput = "firefox|130.0|131.0|false`n1 packages outdated."
            UpdatesChecked = $true
        }

        $snapshot = Get-KapselCatalogInventory -Applications $applications -Provider choco -ProviderInventory $provider

        $snapshot.States.firefox.Status | Should Be 'UpdateAvailable'
        $snapshot.States.zed.Status | Should Be 'Unsupported'
        $snapshot.States.other.Status | Should Be 'Installed'
        $snapshot.UpdateCount | Should Be 1
    }

    It 'keeps installed state when the update query is unavailable' {
        $provider = [PSCustomObject] @{
            InstalledOutput = 'firefox|130.0'
            UpdateOutput = ''
            UpdatesChecked = $false
        }

        $snapshot = Get-KapselCatalogInventory -Applications $applications -Provider choco -ProviderInventory $provider

        $snapshot.States.firefox.Status | Should Be 'Installed'
        $snapshot.UpdatesChecked | Should Be $false
    }

    It 'filters installed and updateable entries without changing the source list' {
        $provider = [PSCustomObject] @{
            InstalledOutput = "firefox|130.0`nother|2.0"
            UpdateOutput = 'firefox|130.0|131.0|false'
            UpdatesChecked = $true
        }
        $snapshot = Get-KapselCatalogInventory -Applications $applications -Provider choco -ProviderInventory $provider

        @(Find-KapselInventoryApplications -Applications $applications -Snapshot $snapshot -Filter 'All').Count | Should Be 3
        @(Find-KapselInventoryApplications -Applications $applications -Snapshot $snapshot -Filter 'Installed').Count | Should Be 2
        $updates = @(Find-KapselInventoryApplications -Applications $applications -Snapshot $snapshot -Filter 'Updates')
        $updates.Count | Should Be 1
        $updates[0].Key | Should Be 'firefox'
        $applications.Count | Should Be 3
    }
}

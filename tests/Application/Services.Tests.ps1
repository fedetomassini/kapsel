$ProjectRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)

Import-Module (Join-Path $ProjectRoot 'src\modules\Application\CatalogService.psm1') -Force
Import-Module (Join-Path $ProjectRoot 'src\modules\Application\PackageService.psm1') -Force

Describe 'Application services' {
    It 'creates a catalog snapshot with derived counts' {
        $document = [PSCustomObject] @{
            app = [PSCustomObject] @{
                category = 'Utilities'
                content = 'App'
                winget = 'Vendor.App'
                choco = 'na'
                foss = $true
            }
        }

        $snapshot = New-KapselCatalogSnapshot -CatalogDocument $document

        $snapshot.Counts.Applications | Should Be 1
        $snapshot.Counts.Categories | Should Be 1
        $snapshot.Counts.Foss | Should Be 1
    }

    It 'separates supported and unsupported package operations' {
        $applications = @(
            [PSCustomObject] @{ Name = 'Supported'; WingetId = 'Vendor.App'; ChocoId = $null },
            [PSCustomObject] @{ Name = 'Unsupported'; WingetId = $null; ChocoId = 'app' }
        )

        $plan = New-KapselPackagePlan -Applications $applications -Provider winget

        $plan.Supported.Count | Should Be 1
        $plan.Unsupported.Count | Should Be 1
    }

    It 'executes a package command through the injected process adapter' {
        $application = [PSCustomObject] @{ Name = 'App'; WingetId = 'Vendor.App'; ChocoId = $null }
        $status = [PSCustomObject] @{ WingetAvailable = $true; ChocoAvailable = $false }
        $invoker = { param($Command) [PSCustomObject] @{ ExitCode = 0; Received = $Command.Display } }

        $result = Invoke-KapselPackageAction -Action Install -Application $application -Provider winget -ProviderStatus $status -ProcessInvoker $invoker

        $result.Succeeded | Should Be $true
        $result.Command | Should Match 'Vendor\.App'
    }

    It 'rejects an invalid process adapter result' {
        $application = [PSCustomObject] @{ Name = 'App'; WingetId = 'Vendor.App'; ChocoId = $null }
        $status = [PSCustomObject] @{ WingetAvailable = $true; ChocoAvailable = $false }
        $invoker = { param($Command) $null }

        { Invoke-KapselPackageAction -Action Install -Application $application -Provider winget -ProviderStatus $status -ProcessInvoker $invoker } | Should Throw
    }
}

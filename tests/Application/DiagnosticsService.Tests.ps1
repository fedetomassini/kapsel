$ProjectRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
Import-Module (Join-Path $ProjectRoot 'src\modules\Application\DiagnosticsService.psm1') -Force

Describe 'Diagnostics report service' {
    It 'summarizes provider, inventory, batch and log state with redaction' {
        $metadata = [PSCustomObject] @{ Name = 'Kapsel'; Version = '1.4.0' }
        $providerStatus = [PSCustomObject] @{ WingetAvailable = $true; ChocoAvailable = $false }
        $providerDiagnostics = @{
            winget = [PSCustomObject] @{ Provider = 'winget'; Version = '1.9.0'; ExecutablePath = "$env:USERPROFILE\winget.exe"; Supported = $true }
        }
        $inventory = [PSCustomObject] @{
            Status = 'Ready'
            CheckedAt = [DateTime]::UtcNow
            Snapshot = [PSCustomObject] @{ Provider = 'winget'; InstalledCount = 3; UpdateCount = 1; UpdatesChecked = $true }
        }
        $operation = [PSCustomObject] @{
            Action = 'Install'; Provider = 'winget'; Total = 2; Completed = 2
            Succeeded = 0; Unchanged = 0; RestartRequired = 1; Failed = 1; Cancelled = 0
            RestartItems = @([PSCustomObject] @{ Name = 'Needs Restart' })
            FailedItems = @([PSCustomObject] @{ Name = 'Broken App' })
        }
        $logs = @([PSCustomObject] @{ Name = '20261031-120000-abc.stdout.log'; Length = 120; LastWriteTime = [DateTime]::UtcNow })

        $report = New-KapselDiagnosticsReport -Metadata $metadata -ProviderStatus $providerStatus `
            -InventoryDiagnostics $providerDiagnostics -Inventory $inventory -Operation $operation `
            -LogFiles $logs -DataDirectory "$env:USERPROFILE\AppData\Local\Kapsel" `
            -LogDirectory "$env:USERPROFILE\AppData\Local\Kapsel\Logs"

        $report | Should Match 'Kapsel 1\.4\.0'
        $report | Should Match 'winget: available'
        $report | Should Match 'installed=3 updates=1 updatesChecked=True'
        $report | Should Match 'restartRequired=1 failed=1'
        $report | Should Match 'restart required: Needs Restart'
        $report | Should Match 'failed: Broken App'
        $report | Should Match '20261031-120000-abc\.stdout\.log'
        $report | Should Not Match ([regex]::Escape($env:USERPROFILE))
        $report | Should Match '%USERPROFILE%'
    }

    It 'reports an empty session explicitly' {
        $report = New-KapselDiagnosticsReport -Metadata ([PSCustomObject] @{ Name = 'Kapsel'; Version = '1.4.0' }) `
            -ProviderStatus ([PSCustomObject] @{ WingetAvailable = $false; ChocoAvailable = $false }) `
            -Inventory $null -Operation $null -LogFiles @()

        $report | Should Match 'Last batch:\r?\n  none in this session'
        $report | Should Match 'Package logs \(newest first; retained 30 days\):\r?\n  none'
    }
}

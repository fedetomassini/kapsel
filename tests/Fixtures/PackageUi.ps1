# Real UI and background worker with a simulated adapter: never installs software.
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
Import-Module (Join-Path $projectRoot 'src\modules\Shared\ProductMetadata.psm1') -Force
Import-Module (Join-Path $projectRoot 'src\modules\Presentation\WinForms\Gui.psm1') -Force
& (Get-Module Gui) {
    $script:upgradeAttempt = 0
    function script:Get-KapselPackageProviderStatus {
        [PSCustomObject] @{ WingetAvailable = $true; ChocoAvailable = $false }
    }
    function script:Start-KapselInventoryScan {
        param($Applications, $Provider)
        $failureFlag = Join-Path $env:KAPSEL_DATA_DIRECTORY 'fail-next-inventory'
        if (Test-Path -LiteralPath $failureFlag) {
            Remove-Item -LiteralPath $failureFlag
            return InventoryRunner\Start-KapselInventoryScan -Applications $Applications -Provider $Provider -ProviderInvoker { throw 'Simulated inventory refresh failure' }
        }
        InventoryRunner\Start-KapselInventoryScan -Applications $Applications -Provider $Provider -ProviderInvoker {
            param($SelectedProvider, $Token)
            $Token.ThrowIfCancellationRequested()
            Start-Sleep -Milliseconds 700
            [PSCustomObject] @{
                InstalledDocument = [PSCustomObject] @{ Sources = @([PSCustomObject] @{ Packages = @(
                    [PSCustomObject] @{ PackageIdentifier = 'Mozilla.Firefox'; Version = '130.0' },
                    [PSCustomObject] @{ PackageIdentifier = 'Mozilla.Firefox.ESR'; Version = '128.0' }
                ) }) }
                UpdateOutput = 'Firefox  Mozilla.Firefox  130.0  131.0  winget'
                UpdatesChecked = $true
                Warning = ''
                Diagnostics = [PSCustomObject] @{ Provider = $SelectedProvider; Version = 'simulated'; ExecutablePath = '(simulated provider)'; Supported = $true }
            }
        }
    }
    function script:Start-KapselPackageBatch {
        param($Plan, $Action, $ProviderStatus, $CancellationToken)
        if ($Action -eq 'Upgrade') { $script:upgradeAttempt++ }
        $invoker = {
            param($Command)
            Start-Sleep -Seconds 2
            $code = if ($Command.Arguments[0] -ne 'upgrade') { 0 } elseif ($Command.Arguments[2] -eq 'Mozilla.Firefox') { -1978335189 } else { 7 }
            [PSCustomObject] @{ ExitCode = $code; Diagnostics = 'Simulated provider failure' }
        }
        if ($Action -eq 'Upgrade' -and $script:upgradeAttempt -gt 1) {
            $invoker = {
                param($Command)
                Start-Sleep -Seconds 2
                [PSCustomObject] @{ ExitCode = -1978335189; Diagnostics = '' }
            }
        }
        PackageOperationRunner\Start-KapselPackageBatch -Plan $Plan -Action $Action -ProviderStatus $ProviderStatus -ProcessInvoker $invoker -CancellationToken $CancellationToken
    }
}
Gui\Show-KapselGui -Metadata (Get-KapselProductMetadata) -DelayWarningSeconds 1

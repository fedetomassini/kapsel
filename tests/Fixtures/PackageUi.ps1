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
    function script:Start-KapselPackageBatch {
        param($Plan, $Action, $ProviderStatus)
        if ($Action -eq 'Upgrade') { $script:upgradeAttempt++ }
        $invoker = {
            param($Command)
            Start-Sleep -Seconds 2
            $code = if ($Command.Arguments[0] -ne 'upgrade') { 0 } elseif ($Command.Arguments[2] -eq 'Mozilla.Firefox') { -1978335189 } else { 7 }
            [PSCustomObject] @{ ExitCode = $code; Diagnostics = 'Simulated provider failure' }
        }
        if ($script:upgradeAttempt -gt 1) {
            $invoker = {
                param($Command)
                Start-Sleep -Seconds 2
                [PSCustomObject] @{ ExitCode = -1978335189; Diagnostics = '' }
            }
        }
        PackageOperationRunner\Start-KapselPackageBatch -Plan $Plan -Action $Action -ProviderStatus $ProviderStatus -ProcessInvoker $invoker
    }
}
Gui\Show-KapselGui -Metadata (Get-KapselProductMetadata)

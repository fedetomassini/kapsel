# Runs inventory discovery off the UI thread and delivers one immutable result.
Set-StrictMode -Version Latest

function Start-KapselInventoryScan {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)] [object[]] $Applications,
        [Parameter(Mandatory = $true)] [ValidateSet('winget', 'choco')] [string] $Provider,
        [scriptblock] $ProviderInvoker = { param($SelectedProvider, $Token) Get-KapselProviderInventory -Provider $SelectedProvider -CancellationToken $Token }
    )

    $worker = [PowerShell]::Create()
    $cancellation = New-Object System.Threading.CancellationTokenSource
    $moduleRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
    $script = {
        param($ModuleRoot, $Applications, $Provider, $InvokerSource, $Token)
        $ErrorActionPreference = 'Stop'
        Set-StrictMode -Version Latest
        Import-Module (Join-Path $ModuleRoot 'Application\InventoryService.psm1') -Force
        Import-Module (Join-Path $ModuleRoot 'Infrastructure\PackageInventoryAdapter.psm1') -Force
        $invoker = [scriptblock]::Create($InvokerSource)
        $providerInventory = & $invoker $Provider $Token
        $snapshot = Get-KapselCatalogInventory -Applications $Applications -Provider $Provider -ProviderInventory $providerInventory
        return [PSCustomObject] @{ Snapshot = $snapshot; Warning = [string] $providerInventory.Warning }
    }
    try {
        [void] $worker.AddScript($script.ToString()).AddArgument($moduleRoot).AddArgument($Applications).AddArgument($Provider).AddArgument($ProviderInvoker.ToString()).AddArgument($cancellation.Token)
        $handle = $worker.BeginInvoke()
        return [PSCustomObject] @{ Worker = $worker; Handle = $handle; Provider = $Provider; Cancellation = $cancellation }
    }
    catch {
        $worker.Dispose()
        $cancellation.Dispose()
        throw
    }
}

Export-ModuleMember -Function 'Start-KapselInventoryScan'

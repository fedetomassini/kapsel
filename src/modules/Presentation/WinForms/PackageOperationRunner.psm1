# Runs package use cases off the UI thread; only the UI consumes queued events.
Set-StrictMode -Version Latest

function Start-KapselPackageBatch {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)] [object] $Plan,
        [Parameter(Mandatory = $true)] [ValidateSet('Install', 'Upgrade')] [string] $Action,
        [Parameter(Mandatory = $true)] [object] $ProviderStatus,
        [scriptblock] $ProcessInvoker = { param($Command) Invoke-KapselPackageProcess -Command $Command }
    )

    $events = New-Object 'System.Collections.Concurrent.ConcurrentQueue[object]'
    $worker = [PowerShell]::Create()
    $moduleRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
    $script = {
        param($ModuleRoot, $Plan, $Action, $ProviderStatus, $Events, $InvokerSource)
        $ErrorActionPreference = 'Stop'
        Set-StrictMode -Version Latest
        Import-Module (Join-Path $ModuleRoot 'Application\PackageService.psm1') -Force
        Import-Module (Join-Path $ModuleRoot 'Infrastructure\PackageManagerAdapter.psm1') -Force
        $invoker = [scriptblock]::Create($InvokerSource)
        foreach ($application in @($Plan.Supported)) {
            $Events.Enqueue([PSCustomObject] @{ Kind = 'Started'; Application = $application.Name })
            try {
                $result = Invoke-KapselPackageAction -Action $Action -Application $application -Provider $Plan.Provider -ProviderStatus $ProviderStatus -ProcessInvoker $invoker
                $Events.Enqueue([PSCustomObject] @{ Kind = 'Completed'; Application = $application.Name; Result = $result })
            }
            catch {
                $Events.Enqueue([PSCustomObject] @{ Kind = 'Failed'; Application = $application.Name; Message = $_.Exception.Message })
            }
        }
    }
    try {
        [void] $worker.AddScript($script.ToString()).AddArgument($moduleRoot).AddArgument($Plan).AddArgument($Action).AddArgument($ProviderStatus).AddArgument($events).AddArgument($ProcessInvoker.ToString())
        $handle = $worker.BeginInvoke()
        return [PSCustomObject] @{ Worker = $worker; Handle = $handle; Events = $events }
    }
    catch {
        $worker.Dispose()
        throw
    }
}

Export-ModuleMember -Function 'Start-KapselPackageBatch'

# Package install/update use cases. Process execution is injected by the composition root.
Set-StrictMode -Version Latest

Import-Module (Join-Path (Split-Path -Parent $PSScriptRoot) 'Domain\PackageOperation.psm1') -Force

function New-KapselPackagePlan {
    [CmdletBinding()]
    param(
        [object[]] $Applications = @(),
        [Parameter(Mandatory = $true)]
        [ValidateSet('winget', 'choco')]
        [string] $Provider
    )

    $supported = New-Object System.Collections.Generic.List[object]
    $unsupported = New-Object System.Collections.Generic.List[object]

    foreach ($application in @($Applications)) {
        $propertyName = if ($Provider -eq 'winget') { 'WingetId' } else { 'ChocoId' }
        if (-not [string]::IsNullOrWhiteSpace([string] $application.$propertyName)) {
            [void] $supported.Add($application)
        }
        else {
            [void] $unsupported.Add($application)
        }
    }

    return [PSCustomObject] @{
        Provider    = $Provider
        Supported   = $supported.ToArray()
        Unsupported = $unsupported.ToArray()
    }
}

function Invoke-KapselPackageAction {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet('Install', 'Upgrade')]
        [string] $Action,

        [Parameter(Mandatory = $true)]
        [object] $Application,

        [Parameter(Mandatory = $true)]
        [ValidateSet('winget', 'choco')]
        [string] $Provider,

        [Parameter(Mandatory = $true)]
        [object] $ProviderStatus,

        [Parameter(Mandatory = $true)]
        [scriptblock] $ProcessInvoker
    )

    $availabilityProperty = if ($Provider -eq 'winget') { 'WingetAvailable' } else { 'ChocoAvailable' }
    if (-not [bool] $ProviderStatus.$availabilityProperty) {
        throw "$Provider is not available on this system."
    }

    $command = New-KapselPackageCommand -Action $Action -Application $Application -Provider $Provider
    $processResult = & $ProcessInvoker $command
    if ($null -eq $processResult -or $null -eq $processResult.PSObject.Properties['ExitCode']) {
        throw "The $Provider process adapter did not return an exit code."
    }
    $exitCode = [int] $processResult.ExitCode
    $outcome = Get-KapselPackageOutcome -Provider $Provider -Action $Action -ExitCode $exitCode

    return [PSCustomObject] @{
        Application = $Application.Name
        Provider    = $Provider
        Action      = $Action
        ExitCode    = $exitCode
        Succeeded   = $outcome.Succeeded
        Status      = $outcome.Status
        Message     = $outcome.Message
        Command     = $command.Display
        Diagnostics = if ($null -ne $processResult.PSObject.Properties['Diagnostics']) { [string] $processResult.Diagnostics } else { '' }
    }
}

function Get-KapselPackageBatchSummary {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)] [ValidateSet('Install', 'Upgrade')] [string] $Action,
        [int] $Succeeded = 0,
        [int] $Unchanged = 0,
        [int] $RestartRequired = 0,
        [int] $Failed = 0,
        [int] $Cancelled = 0
    )

    $succeededLabel = if ($Unchanged -gt 0 -or $RestartRequired -gt 0) { 'completed' } else { 'succeeded' }
    $text = "$Action finished: $Succeeded $succeededLabel"
    if ($Unchanged -gt 0) { $text += ", $Unchanged unchanged" }
    if ($RestartRequired -gt 0) { $text += ", $RestartRequired restart required" }
    $text += ", $Failed failed"
    if ($Cancelled -gt 0) { $text += ", $Cancelled cancelled" }

    $level = if ($Failed -gt 0 -or $RestartRequired -gt 0 -or $Cancelled -gt 0) { 'Warning' } else { 'Success' }
    return [PSCustomObject] @{ Text = $text; Level = $level }
}

Export-ModuleMember -Function @(
    'New-KapselPackagePlan',
    'Invoke-KapselPackageAction',
    'Get-KapselPackageBatchSummary'
)

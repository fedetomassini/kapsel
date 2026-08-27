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

    return [PSCustomObject] @{
        Application = $Application.Name
        Provider    = $Provider
        Action      = $Action
        ExitCode    = $exitCode
        Succeeded   = $exitCode -eq 0
        Command     = $command.Display
    }
}

Export-ModuleMember -Function @(
    'New-KapselPackagePlan',
    'Invoke-KapselPackageAction'
)

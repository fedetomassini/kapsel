# winget and Chocolatey process adapter.
Set-StrictMode -Version Latest

function Test-KapselCommandAvailable {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string] $Name
    )

    return $null -ne (Get-Command -Name $Name -ErrorAction SilentlyContinue)
}

function Get-KapselPackageProviderStatus {
    [CmdletBinding()]
    param()

    return [PSCustomObject] @{
        WingetAvailable = Test-KapselCommandAvailable -Name 'winget'
        ChocoAvailable  = Test-KapselCommandAvailable -Name 'choco'
    }
}

function Invoke-KapselPackageProcess {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [object] $Command
    )

    if ([string]::IsNullOrWhiteSpace([string] $Command.Executable)) {
        throw 'The package command does not define an executable.'
    }

    $startParameters = @{
        FilePath     = [string] $Command.Executable
        ArgumentList = [string[]] $Command.Arguments
        Wait         = $true
        PassThru     = $true
        NoNewWindow  = $true
        ErrorAction  = 'Stop'
    }
    $process = Start-Process @startParameters

    return [PSCustomObject] @{ ExitCode = [int] $process.ExitCode }
}

Export-ModuleMember -Function @(
    'Test-KapselCommandAvailable',
    'Get-KapselPackageProviderStatus',
    'Invoke-KapselPackageProcess'
)

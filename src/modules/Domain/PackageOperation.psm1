# Pure package-operation rules. Commands are described here and executed by infrastructure.
Set-StrictMode -Version Latest

Import-Module (Join-Path $PSScriptRoot 'ApplicationCatalog.psm1') -Force

function New-KapselPackageCommand {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet('Install', 'Upgrade')]
        [string] $Action,

        [Parameter(Mandatory = $true)]
        [object] $Application,

        [Parameter(Mandatory = $true)]
        [ValidateSet('winget', 'choco')]
        [string] $Provider
    )

    if (-not (Test-KapselApplicationProviderSupport -Application $Application -Provider $Provider)) {
        throw "Application '$($Application.Name)' does not define a $Provider package id."
    }

    if ($Provider -eq 'winget') {
        $verb = if ($Action -eq 'Install') { 'install' } else { 'upgrade' }
        $arguments = @(
            $verb,
            '--id', [string] $Application.WingetId,
            '--exact',
            '--silent',
            '--accept-package-agreements',
            '--accept-source-agreements'
        )
    }
    else {
        $verb = if ($Action -eq 'Install') { 'install' } else { 'upgrade' }
        $arguments = @($verb, [string] $Application.ChocoId, '-y')
    }

    return [PSCustomObject] @{
        Executable = $Provider
        Arguments  = [string[]] $arguments
        Display    = ('{0} {1}' -f $Provider, ($arguments -join ' '))
    }
}

function Get-KapselPackageOutcome {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)] [ValidateSet('winget', 'choco')] [string] $Provider,
        [Parameter(Mandatory = $true)] [ValidateSet('Install', 'Upgrade')] [string] $Action,
        [Parameter(Mandatory = $true)] [int] $ExitCode
    )

    # Provider return-code contracts, independent of the language of console output:
    # https://github.com/microsoft/winget-cli/blob/master/doc/windows/package-manager/winget/returnCodes.md
    # https://docs.chocolatey.org/en-us/choco/commands/upgrade/#exit-codes
    if (($Provider -eq 'winget' -and $ExitCode -in @(-1978335189, -1978335153)) -or
        ($Provider -eq 'choco' -and $Action -eq 'Upgrade' -and $ExitCode -eq 2)) {
        return [PSCustomObject] @{ Status = 'UpToDate'; Succeeded = $true; Message = 'No newer version is available from the configured sources.' }
    }
    if ($Provider -eq 'winget' -and $Action -eq 'Install' -and $ExitCode -eq -1978335135) {
        return [PSCustomObject] @{ Status = 'AlreadyInstalled'; Succeeded = $true; Message = 'Already installed. No installation was needed.' }
    }
    if ($Provider -eq 'choco' -and $ExitCode -in @(1641, 3010)) {
        $message = if ($ExitCode -eq 1641) { 'Completed successfully. A restart was initiated.' } else { 'Completed successfully. Restart Windows to finish applying the changes.' }
        return [PSCustomObject] @{ Status = 'RestartRequired'; Succeeded = $true; Message = $message }
    }
    if ($ExitCode -eq 0) {
        return [PSCustomObject] @{ Status = 'Completed'; Succeeded = $true; Message = 'Completed successfully.' }
    }
    return [PSCustomObject] @{ Status = 'Failed'; Succeeded = $false; Message = "$Action could not be completed by $Provider (exit code $ExitCode)." }
}

Export-ModuleMember -Function @('New-KapselPackageCommand', 'Get-KapselPackageOutcome')

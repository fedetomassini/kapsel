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

Export-ModuleMember -Function 'New-KapselPackageCommand'

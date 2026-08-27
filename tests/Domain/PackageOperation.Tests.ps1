$ProjectRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)

Import-Module (Join-Path $ProjectRoot 'src\modules\Domain\PackageOperation.psm1') -Force

$TestApplication = [PSCustomObject] @{
    Name = '7-Zip'
    WingetId = '7zip.7zip'
    ChocoId = '7zip'
}

Describe 'Package operation domain' {
    It 'builds a non-interactive winget install command' {
        $command = New-KapselPackageCommand -Action Install -Application $TestApplication -Provider winget

        $command.Executable | Should Be 'winget'
        ($command.Arguments -contains '7zip.7zip') | Should Be $true
        ($command.Arguments -contains '--accept-source-agreements') | Should Be $true
    }

    It 'builds a confirmed Chocolatey update command' {
        $command = New-KapselPackageCommand -Action Upgrade -Application $TestApplication -Provider choco

        $command.Executable | Should Be 'choco'
        ($command.Arguments -contains 'upgrade') | Should Be $true
        ($command.Arguments -contains '-y') | Should Be $true
    }

    It 'rejects a provider missing from the application' {
        $application = [PSCustomObject] @{ Name = 'Git'; WingetId = 'Git.Git'; ChocoId = $null }

        { New-KapselPackageCommand -Action Install -Application $application -Provider choco } | Should Throw
    }
}

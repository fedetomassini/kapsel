$ProjectRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)

Import-Module (Join-Path $ProjectRoot 'src\modules\Domain\PackageOperation.psm1') -Force

$TestApplication = [PSCustomObject] @{
    Name = '7-Zip'
    WingetId = '7zip.7zip'
    ChocoId = '7zip'
}

Describe 'Package operation domain' {
    It 'interprets <Provider> <Action> exit code <Code> as <Status>' -TestCases @(
        @{ Provider = 'winget'; Action = 'Upgrade'; Code = -1978335189; Status = 'UpToDate'; Success = $true },
        @{ Provider = 'winget'; Action = 'Upgrade'; Code = -1978335153; Status = 'UpToDate'; Success = $true },
        @{ Provider = 'winget'; Action = 'Install'; Code = -1978335189; Status = 'UpToDate'; Success = $true },
        @{ Provider = 'winget'; Action = 'Install'; Code = -1978335135; Status = 'AlreadyInstalled'; Success = $true },
        @{ Provider = 'winget'; Action = 'Upgrade'; Code = -1978335135; Status = 'Failed'; Success = $false },
        @{ Provider = 'winget'; Action = 'Upgrade'; Code = -1978335212; Status = 'Failed'; Success = $false },
        @{ Provider = 'winget'; Action = 'Upgrade'; Code = -1978335152; Status = 'Failed'; Success = $false },
        @{ Provider = 'winget'; Action = 'Upgrade'; Code = 2; Status = 'Failed'; Success = $false },
        @{ Provider = 'choco'; Action = 'Upgrade'; Code = 2; Status = 'UpToDate'; Success = $true },
        @{ Provider = 'choco'; Action = 'Install'; Code = 2; Status = 'Failed'; Success = $false },
        @{ Provider = 'choco'; Action = 'Upgrade'; Code = 3010; Status = 'RestartRequired'; Success = $true },
        @{ Provider = 'choco'; Action = 'Install'; Code = 1641; Status = 'RestartRequired'; Success = $true },
        @{ Provider = 'choco'; Action = 'Upgrade'; Code = -1978335189; Status = 'Failed'; Success = $false },
        @{ Provider = 'winget'; Action = 'Install'; Code = 0; Status = 'Completed'; Success = $true }
    ) {
        param($Provider, $Action, $Code, $Status, $Success)
        $outcome = Get-KapselPackageOutcome -Provider $Provider -Action $Action -ExitCode $Code
        $outcome.Status | Should Be $Status
        $outcome.Succeeded | Should Be $Success
        $outcome.Message | Should Not BeNullOrEmpty
    }

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

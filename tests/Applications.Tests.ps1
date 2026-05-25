$ProjectRoot = Split-Path -Parent $PSScriptRoot

Import-Module (Join-Path $ProjectRoot 'src\modules\Applications.psm1') -Force

Describe 'Kapsel project structure' {
    It 'keeps only the application installer surface' {
        Test-Path (Join-Path $ProjectRoot 'src\Kapsel.ps1') | Should Be $true
        Test-Path (Join-Path $ProjectRoot 'src\applications.json') | Should Be $true
        Test-Path (Join-Path $ProjectRoot 'src\modules\Applications.psm1') | Should Be $true
        Test-Path (Join-Path $ProjectRoot 'src\modules\Gui.psm1') | Should Be $true
    }
}

Describe 'Application catalog' {
    It 'loads applications from applications.json' {
        $catalog = @(Get-KapselApplicationCatalog -Path (Join-Path $ProjectRoot 'src\applications.json'))

        $catalog.Count | Should BeGreaterThan 0
        @($catalog | Where-Object { $_.Name -eq '7-Zip' }).Count | Should Be 1
    }

    It 'normalizes optional package fields' {
        $catalog = @(Get-KapselApplicationCatalog -Path (Join-Path $ProjectRoot 'src\applications.json'))
        $itemsWithoutChoco = @($catalog | Where-Object { [string]::IsNullOrWhiteSpace($_.ChocoId) })

        $itemsWithoutChoco.Count | Should BeGreaterThan 0
    }

    It 'builds winget install arguments without executing winget' {
        $application = [PSCustomObject] @{
            Name     = '7-Zip'
            WingetId = '7zip.7zip'
            ChocoId  = '7zip'
        }

        $arguments = New-KapselPackageArgument -Action Install -Application $application -Provider winget

        $arguments -contains 'install' | Should Be $true
        $arguments -contains '7zip.7zip' | Should Be $true
        $arguments -contains '--accept-source-agreements' | Should Be $true
    }

    It 'builds Chocolatey upgrade arguments without executing Chocolatey' {
        $application = [PSCustomObject] @{
            Name     = '7-Zip'
            WingetId = '7zip.7zip'
            ChocoId  = '7zip'
        }

        $arguments = New-KapselPackageArgument -Action Upgrade -Application $application -Provider choco

        $arguments -contains 'upgrade' | Should Be $true
        $arguments -contains '7zip' | Should Be $true
        $arguments -contains '-y' | Should Be $true
    }

    It 'can filter applications by category and FOSS state' {
        $catalog = @(Get-KapselApplicationCatalog -Path (Join-Path $ProjectRoot 'src\applications.json'))
        $filtered = @(Search-KapselApplicationCatalog -Applications $catalog -Category 'Browsers' -FossOnly)

        $filtered.Count | Should BeGreaterThan 0
        @($filtered | Where-Object { $_.Category -ne 'Browsers' }).Count | Should Be 0
        @($filtered | Where-Object { $_.Foss -ne $true }).Count | Should Be 0
    }
}


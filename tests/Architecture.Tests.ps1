$ProjectRoot = Split-Path -Parent $PSScriptRoot

Describe 'Kapsel architecture' {
    It 'organizes production modules by responsibility' {
        foreach ($path in @(
            'src\modules\Domain\ApplicationCatalog.psm1',
            'src\modules\Domain\PackageOperation.psm1',
            'src\modules\Application\CatalogService.psm1',
            'src\modules\Application\PackageService.psm1',
            'src\modules\Infrastructure\JsonCatalogRepository.psm1',
            'src\modules\Infrastructure\PackageManagerAdapter.psm1',
            'src\modules\Presentation\WinForms\Gui.psm1',
            'src\modules\Presentation\WinForms\WindowChrome.psm1',
            'src\modules\Shared\ProductMetadata.psm1'
        )) {
            Test-Path -LiteralPath (Join-Path $ProjectRoot $path) | Should Be $true
        }
    }

    It 'provides stable development and release-cleaning scripts' {
        Test-Path -LiteralPath (Join-Path $ProjectRoot 'scripts\Start-Kapsel.ps1') | Should Be $true
        Test-Path -LiteralPath (Join-Path $ProjectRoot 'scripts\Clean-Releases.ps1') | Should Be $true
        Test-Path -LiteralPath (Join-Path $ProjectRoot 'scripts\Generate-CatalogMarkdown.ps1') | Should Be $true

        $package = Get-Content -LiteralPath (Join-Path $ProjectRoot 'package.json') -Raw | ConvertFrom-Json
        $package.scripts.start | Should Match 'Start-Kapsel\.ps1'
        $package.scripts.dev | Should Match 'Start-Kapsel\.ps1'
        $package.scripts.app | Should Match 'Start-Kapsel\.ps1'
        $package.scripts.'clean:releases' | Should Match 'Clean-Releases\.ps1'
        $package.scripts.'docs:catalog' | Should Match 'Generate-CatalogMarkdown\.ps1'
        $package.scripts.'docs:catalog:check' | Should Match 'Generate-CatalogMarkdown\.ps1 -Check'
    }

    It 'keeps domain modules independent from UI and external adapters' {
        $domainSource = Get-ChildItem -LiteralPath (Join-Path $ProjectRoot 'src\modules\Domain') -Filter *.psm1 |
            Get-Content -Raw
        $joinedSource = $domainSource -join [Environment]::NewLine

        $joinedSource | Should Not Match 'System\.Windows\.Forms'
        $joinedSource | Should Not Match 'Start-Process'
        $joinedSource | Should Not Match 'Get-Content'
        $joinedSource | Should Not Match 'Infrastructure\\'
    }

    It 'keeps application services independent from presentation and infrastructure modules' {
        $applicationSource = Get-ChildItem -LiteralPath (Join-Path $ProjectRoot 'src\modules\Application') -Filter *.psm1 |
            Get-Content -Raw
        $joinedSource = $applicationSource -join [Environment]::NewLine

        $joinedSource | Should Not Match 'Presentation\\'
        $joinedSource | Should Not Match 'Infrastructure\\'
        $joinedSource | Should Not Match 'System\.Windows\.Forms'
    }

    It 'owns the window frame instead of styling native Windows chrome' {
        $chromeSource = Get-Content -LiteralPath (
            Join-Path $ProjectRoot 'src\modules\Presentation\WinForms\WindowChrome.psm1'
        ) -Raw
        $themeSource = Get-Content -LiteralPath (
            Join-Path $ProjectRoot 'src\modules\Presentation\WinForms\Theme.psm1'
        ) -Raw

        $chromeSource | Should Match 'FormBorderStyle\.None'
        $chromeSource | Should Match 'KapselMaximizeButton'
        $chromeSource | Should Match 'WmNcHitTest'
        $themeSource | Should Not Match 'DwmSetWindowAttribute'
    }

    It 'separates read-only quality checks from tag-driven release publication' {
        $qualitySource = Get-Content -LiteralPath (Join-Path $ProjectRoot '.github\workflows\quality.yml') -Raw
        $releaseSource = Get-Content -LiteralPath (Join-Path $ProjectRoot '.github\workflows\release.yml') -Raw

        $qualitySource | Should Match 'contents: read'
        $qualitySource | Should Match 'pull_request:'
        $qualitySource | Should Match 'docs:catalog:check'
        $releaseSource | Should Match "tags:\s+- 'v\*\.\*\.\*'"
        $releaseSource | Should Match 'contents: write'
        $releaseSource | Should Not Match 'workflow_dispatch'
    }
}

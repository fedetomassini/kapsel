$ProjectRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)

Import-Module (Join-Path $ProjectRoot 'src\modules\Infrastructure\JsonCatalogRepository.psm1') -Force
Import-Module (Join-Path $ProjectRoot 'src\modules\Application\CatalogService.psm1') -Force

Describe 'JSON catalog repository' {
    It 'resolves and reads the production catalog' {
        $path = Get-KapselApplicationCatalogPath
        $document = Read-KapselApplicationCatalogDocument -Path $path
        $snapshot = New-KapselCatalogSnapshot -CatalogDocument $document

        Test-Path -LiteralPath $path | Should Be $true
        $snapshot.Applications.Count | Should BeGreaterThan 0
        @($snapshot.Applications | Where-Object { $_.Name -eq '7-Zip' }).Count | Should Be 1
    }

    It 'fails clearly when the catalog does not exist' {
        $missingPath = Join-Path $ProjectRoot 'tests\fixtures\missing-catalog.json'

        { Read-KapselApplicationCatalogDocument -Path $missingPath } | Should Throw
    }
}

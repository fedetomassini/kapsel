$ProjectRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)

Import-Module (Join-Path $ProjectRoot 'src\modules\Domain\ApplicationCatalog.psm1') -Force

function New-TestCatalogDocument {
    return [PSCustomObject] @{
        sevenzip = [PSCustomObject] @{
            category = 'Utilities'
            content = '7-Zip'
            description = 'File archiver'
            link = 'https://www.7-zip.org/'
            winget = '7zip.7zip'
            choco = '7zip'
            foss = $true
        }
        browser = [PSCustomObject] @{
            category = 'Browsers'
            content = 'Example [Browser]'
            description = 'Private browser'
            link = 'https://example.com/'
            winget = 'Example.Browser'
            choco = 'na'
            foss = $false
        }
    }
}

Describe 'Application catalog domain' {
    It 'normalizes catalog entries and unavailable provider identifiers' {
        $catalog = @(ConvertFrom-KapselCatalogDocument -CatalogDocument (New-TestCatalogDocument))

        $catalog.Count | Should Be 2
        $catalog[0].Name | Should Be '7-Zip'
        $catalog[1].ChocoId | Should BeNullOrEmpty
        $catalog[1].PreferredProvider | Should Be 'winget'
    }

    It 'searches literal text without wildcard interpretation' {
        $catalog = @(ConvertFrom-KapselCatalogDocument -CatalogDocument (New-TestCatalogDocument))
        $result = @(Search-KapselApplicationCatalog -Applications $catalog -Search '[Browser]')

        $result.Count | Should Be 1
        $result[0].Key | Should Be 'browser'
    }

    It 'filters by category and FOSS status' {
        $catalog = @(ConvertFrom-KapselCatalogDocument -CatalogDocument (New-TestCatalogDocument))
        $result = @(Search-KapselApplicationCatalog -Applications $catalog -Category 'Utilities' -FossOnly)

        $result.Count | Should Be 1
        $result[0].Foss | Should Be $true
    }

    It 'reports package provider support' {
        $catalog = @(ConvertFrom-KapselCatalogDocument -CatalogDocument (New-TestCatalogDocument))

        Test-KapselApplicationProviderSupport -Application $catalog[1] -Provider winget | Should Be $true
        Test-KapselApplicationProviderSupport -Application $catalog[1] -Provider choco | Should Be $false
    }

    It 'rejects package identifiers containing command separators' {
        $document = New-TestCatalogDocument
        $document.sevenzip.choco = 'git;sevenzip'

        { ConvertFrom-KapselCatalogDocument -CatalogDocument $document } | Should Throw
    }

    It 'rejects non-boolean FOSS values' {
        $document = New-TestCatalogDocument
        $document.sevenzip.foss = 'true'

        { ConvertFrom-KapselCatalogDocument -CatalogDocument $document } | Should Throw
    }
}

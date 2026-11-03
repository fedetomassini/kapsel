$ProjectRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
Import-Module (Join-Path $ProjectRoot 'src\modules\Infrastructure\CatalogHealth.psm1') -Force

Describe 'Catalog health classification' {
    It 'treats reachable links as ok and missing links as broken' {
        foreach ($status in @(200, 204, 301, 302, 399)) {
            (Get-KapselLinkCheckOutcome -StatusCode $status) | Should Be 'Ok'
        }
        foreach ($status in @(404, 410)) {
            (Get-KapselLinkCheckOutcome -StatusCode $status) | Should Be 'Broken'
        }
    }

    It 'keeps auth, rate-limit, server and transport failures inconclusive' {
        foreach ($status in @(0, 400, 401, 403, 405, 429, 500, 503)) {
            (Get-KapselLinkCheckOutcome -StatusCode $status -Error 'probe failed') | Should Be 'Inconclusive'
        }
    }

    It 'classifies provider responses only when the identifier is found' {
        (Get-KapselProviderCheckOutcome -StatusCode 200 -Found $true) | Should Be 'Ok'
        (Get-KapselProviderCheckOutcome -StatusCode 200 -Found $false) | Should Be 'Broken'
        (Get-KapselProviderCheckOutcome -StatusCode 404 -Found $false) | Should Be 'Broken'
        (Get-KapselProviderCheckOutcome -StatusCode 403 -Found $false) | Should Be 'Inconclusive'
        (Get-KapselProviderCheckOutcome -StatusCode 0 -Found $false -Error 'Timed out') | Should Be 'Inconclusive'
    }

    It 'maps winget identifiers to the manifest path without inventing segments' {
        (Get-KapselWingetManifestPath -PackageId 'Mozilla.Firefox') | Should Be 'manifests/m/Mozilla/Firefox'
        (Get-KapselWingetManifestPath -PackageId '7zip.7zip') | Should Be 'manifests/7/7zip/7zip'
        (Get-KapselWingetManifestPath -PackageId 'Microsoft.DotNet.SDK.8') | Should Be 'manifests/m/Microsoft/DotNet/SDK/8'
        (Get-KapselWingetManifestPath -PackageId 'Microsoft.VCRedist.2015+.x86') | Should Be 'manifests/m/Microsoft/VCRedist/2015%2B/x86'
        (Get-KapselWingetManifestPath -PackageId 'Python.Python.3.12') | Should Be 'manifests/p/Python/Python/3/12'
        (Get-KapselWingetManifestPath -PackageId 'NoDot') | Should BeNullOrEmpty
        (Get-KapselWingetManifestPath -PackageId '.Leading') | Should BeNullOrEmpty
        (Get-KapselWingetManifestPath -PackageId 'Trailing.') | Should BeNullOrEmpty
        (Get-KapselWingetManifestPath -PackageId 'Double..Dot') | Should BeNullOrEmpty
    }
}

Describe 'Catalog health report' {
    It 'counts outcomes and leaves the catalog entries unchanged' {
        $applications = @(
            [PSCustomObject] @{ Key = 'alpha'; Name = 'Alpha'; Link = 'https://alpha.example/'; WingetId = 'Alpha.App'; ChocoId = 'alpha' },
            [PSCustomObject] @{ Key = 'beta'; Name = 'Beta'; Link = 'https://beta.example/'; WingetId = 'Beta.App'; ChocoId = 'beta' }
        )
        $before = $applications | ConvertTo-Json -Depth 4
        $linkResults = @{
            alpha = [PSCustomObject] @{ Outcome = 'Ok'; StatusCode = 200; Error = '' }
            beta  = [PSCustomObject] @{ Outcome = 'Broken'; StatusCode = 404; Error = '' }
        }
        $wingetResults = @{
            alpha = [PSCustomObject] @{ Outcome = 'Ok'; StatusCode = 200; Error = '' }
            beta  = [PSCustomObject] @{ Outcome = 'Inconclusive'; StatusCode = 403; Error = 'rate limited' }
        }
        $chocoResults = @{
            alpha = [PSCustomObject] @{ Outcome = 'Ok'; StatusCode = 200; Error = '' }
            beta  = [PSCustomObject] @{ Outcome = 'Broken'; StatusCode = 200; Error = '' }
        }

        $report = New-KapselCatalogHealthReport -Applications $applications -LinkResults $linkResults -WingetResults $wingetResults -ChocoResults $chocoResults -CatalogPath 'src\applications.json' -CatalogSha256 'abc123'

        $report.Applications | Should Be 2
        $report.CatalogSha256 | Should Be 'abc123'
        $report.Links.Ok | Should Be 1
        $report.Links.Broken | Should Be 1
        $report.Links.Inconclusive | Should Be 0
        $report.WingetIds.Inconclusive | Should Be 1
        $report.ChocoIds.Broken | Should Be 1
        $report.Entries[1].Key | Should Be 'beta'
        $report.Entries[1].LinkStatusCode | Should Be 404
        $report.Entries[1].WingetOutcome | Should Be 'Inconclusive'
        ($applications | ConvertTo-Json -Depth 4) | Should Be $before
    }

    It 'marks missing probe results as skipped rather than broken' {
        $applications = @(
            [PSCustomObject] @{ Key = 'alpha'; Name = 'Alpha'; Link = ''; WingetId = ''; ChocoId = '' }
        )

        $report = New-KapselCatalogHealthReport -Applications $applications

        $report.Links.Skipped | Should Be 1
        $report.WingetIds.Skipped | Should Be 1
        $report.ChocoIds.Skipped | Should Be 1
        $report.Entries[0].LinkOutcome | Should Be 'Skipped'
    }
}

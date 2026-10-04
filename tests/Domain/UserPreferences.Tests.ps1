$ProjectRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
Import-Module (Join-Path $ProjectRoot 'src\modules\Domain\UserPreferences.psm1') -Force

Describe 'User preference rules' {
    It 'accepts legacy favorites arrays but rejects explicit unsupported schema versions' {
        $legacy = ConvertFrom-KapselPreferencesDocument -Document ([PSCustomObject] @{ FavoriteKeys = @('firefox') })
        $legacy.SchemaVersion | Should Be 1
        foreach ($version in @(0, 2, '1', $null)) {
            { ConvertFrom-KapselPreferencesDocument -Document ([PSCustomObject] @{ SchemaVersion = $version; FavoriteKeys = @('firefox') }) } | Should Throw
        }
    }

    It 'rejects malformed preference shapes rather than treating them as empty favorites' {
        foreach ($document in @($null, @{}, [PSCustomObject] @{ SchemaVersion = 1; FavoriteKeys = 'firefox' }, [PSCustomObject] @{ SchemaVersion = 1; FavoriteKeys = @(123) })) {
            { ConvertFrom-KapselPreferencesDocument -Document $document } | Should Throw
        }
    }
    It 'normalizes duplicates and removes catalog keys that no longer exist' {
        $result = @(ConvertTo-KapselFavoriteKeys -FavoriteKeys @('firefox', 'FIREFOX', 'removed', '') -AvailableKeys @('firefox', 'vlc'))

        $result.Count | Should Be 1
        $result[0] | Should Be 'firefox'
    }

    It 'adds and removes a favorite without mutating the source collection' {
        $source = @('firefox')
        $added = @(Set-KapselFavoriteKey -FavoriteKeys $source -Key 'vlc' -IsFavorite $true -AvailableKeys @('firefox', 'vlc'))
        $removed = @(Set-KapselFavoriteKey -FavoriteKeys $added -Key 'firefox' -IsFavorite $false -AvailableKeys @('firefox', 'vlc'))

        $source | Should Be @('firefox')
        $added | Should Be @('firefox', 'vlc')
        $removed | Should Be @('vlc')
    }
}

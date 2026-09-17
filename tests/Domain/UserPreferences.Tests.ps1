$ProjectRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
Import-Module (Join-Path $ProjectRoot 'src\modules\Domain\UserPreferences.psm1') -Force

Describe 'User preference rules' {
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

$ProjectRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
Import-Module (Join-Path $ProjectRoot 'src\modules\Application\PreferenceService.psm1') -Force

Describe 'Favorite application service' {
    It 'reports an unsupported schema from an injected reader' {
        { Get-KapselFavorites -PreferencesReader { [PSCustomObject] @{ SchemaVersion = 9; FavoriteKeys = @('firefox') } } } | Should Throw
    }
    It 'loads only favorites that still exist in the catalog' {
        $applications = @([PSCustomObject] @{ Key = 'firefox' }, [PSCustomObject] @{ Key = 'vlc' })
        $favorites = @(Get-KapselFavorites -Applications $applications -PreferencesReader {
            [PSCustomObject] @{ FavoriteKeys = @('vlc', 'removed') }
        })

        $favorites | Should Be @('vlc')
    }

    It 'persists the updated preference document' {
        $applications = @([PSCustomObject] @{ Key = 'firefox' }, [PSCustomObject] @{ Key = 'vlc' })
        $script:savedPreferences = $null
        $result = @(Set-KapselFavorite -FavoriteKeys @('firefox') -Applications $applications -Key 'vlc' -IsFavorite $true -PreferencesWriter {
            param($preferences)
            $script:savedPreferences = $preferences
        })

        $result | Should Be @('firefox', 'vlc')
        $script:savedPreferences.SchemaVersion | Should Be 1
        @($script:savedPreferences.FavoriteKeys) | Should Be @('firefox', 'vlc')
    }
}

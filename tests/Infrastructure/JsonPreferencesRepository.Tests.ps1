$ProjectRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
Import-Module (Join-Path $ProjectRoot 'src\modules\Infrastructure\JsonPreferencesRepository.psm1') -Force

Describe 'JSON preferences repository' {
    It 'returns empty preferences when the file does not exist' {
        $preferences = Read-KapselUserPreferences -Path (Join-Path $TestDrive 'missing\preferences.json')

        $preferences.SchemaVersion | Should Be 1
        @($preferences.FavoriteKeys).Count | Should Be 0
    }

    It 'writes and reads preferences from a nested data directory' {
        $path = Join-Path $TestDrive 'data\preferences.json'
        Write-KapselUserPreferences -Path $path -Preferences ([PSCustomObject] @{ SchemaVersion = 1; FavoriteKeys = @('firefox', 'vlc') })
        $preferences = Read-KapselUserPreferences -Path $path

        $preferences.SchemaVersion | Should Be 1
        @($preferences.FavoriteKeys) | Should Be @('firefox', 'vlc')
    }

    It 'reports malformed JSON without deleting it' {
        $path = Join-Path $TestDrive 'broken.json'
        Set-Content -LiteralPath $path -Value '{broken' -Encoding UTF8

        { Read-KapselUserPreferences -Path $path } | Should Throw
        Test-Path -LiteralPath $path | Should Be $true
    }
}

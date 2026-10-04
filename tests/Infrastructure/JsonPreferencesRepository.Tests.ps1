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

    It 'refuses to replace damaged or future preferences and preserves their exact bytes' {
        foreach ($original in @('{broken', '{"SchemaVersion":2,"FavoriteKeys":["firefox"],"FutureSetting":true}')) {
            $path = Join-Path $TestDrive 'protected.json'
            [IO.File]::WriteAllText($path, $original)
            $before = [Convert]::ToBase64String([IO.File]::ReadAllBytes($path))
            { Write-KapselUserPreferences -Path $path -Preferences ([PSCustomObject] @{ SchemaVersion = 1; FavoriteKeys = @('vlc') }) } | Should Throw
            [Convert]::ToBase64String([IO.File]::ReadAllBytes($path)) | Should Be $before
            @(Get-ChildItem -LiteralPath $TestDrive -Filter '.preferences-*.tmp' -Force).Count | Should Be 0
        }
    }

    It 'leaves the original file intact and cleans temporary data when replacement is denied' {
        $path = Join-Path $TestDrive 'locked.json'
        $original = '{"SchemaVersion":1,"FavoriteKeys":["firefox"]}'
        [IO.File]::WriteAllText($path, $original)
        $lock = [IO.File]::Open($path, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::Read)
        try {
            $failure = $null
            try { Write-KapselUserPreferences -Path $path -Preferences ([PSCustomObject] @{ SchemaVersion = 1; FavoriteKeys = @('vlc') }) }
            catch { $failure = $_.Exception.GetBaseException() }
            ($failure -is [IO.IOException]) | Should Be $true
            [IO.File]::ReadAllText($path) | Should Be $original
            @(Get-ChildItem -LiteralPath $TestDrive -Filter '.preferences-*.tmp' -Force).Count | Should Be 0
        }
        finally { $lock.Dispose() }
    }

    It 'atomically replaces valid preferences and reads legacy files without changing them on load' {
        $path = Join-Path $TestDrive 'legacy.json'
        $legacy = '{"FavoriteKeys":["firefox"]}'
        [IO.File]::WriteAllText($path, $legacy)
        (Read-KapselUserPreferences -Path $path).SchemaVersion | Should Be 1
        [IO.File]::ReadAllText($path) | Should Be $legacy
        Write-KapselUserPreferences -Path $path -Preferences ([PSCustomObject] @{ SchemaVersion = 1; FavoriteKeys = @('vlc') })
        @((Read-KapselUserPreferences -Path $path).FavoriteKeys) | Should Be @('vlc')
    }
}

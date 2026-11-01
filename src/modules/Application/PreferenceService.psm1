# User-preference use cases. Storage is injected by the composition root.
Set-StrictMode -Version Latest

Import-Module (Join-Path (Split-Path -Parent $PSScriptRoot) 'Domain\UserPreferences.psm1') -Force

function Get-KapselPreferenceState {
    [CmdletBinding()]
    param(
        [object[]] $Applications = @(),
        [Parameter(Mandatory = $true)] [scriptblock] $PreferencesReader
    )

    $preferences = ConvertFrom-KapselPreferencesDocument -Document (& $PreferencesReader)
    return [PSCustomObject] @{
        FavoriteKeys = @(ConvertTo-KapselFavoriteKeys -FavoriteKeys $preferences.FavoriteKeys -AvailableKeys @($Applications.Key))
        Provider     = $preferences.Provider
        Window       = $preferences.Window
    }
}

function Get-KapselFavorites {
    [CmdletBinding()]
    param(
        [object[]] $Applications = @(),
        [Parameter(Mandatory = $true)] [scriptblock] $PreferencesReader
    )

    $state = Get-KapselPreferenceState -Applications $Applications -PreferencesReader $PreferencesReader
    return @($state.FavoriteKeys)
}

function Save-KapselPreferences {
    [CmdletBinding()]
    param(
        [object[]] $FavoriteKeys = @(),
        [object[]] $Applications = @(),
        [AllowNull()] [string] $Provider = '',
        [AllowNull()] [object] $Window,
        [Parameter(Mandatory = $true)] [scriptblock] $PreferencesWriter
    )

    $normalized = @(ConvertTo-KapselFavoriteKeys -FavoriteKeys $FavoriteKeys -AvailableKeys @($Applications.Key))
    $document = [PSCustomObject] @{
        SchemaVersion = 2
        FavoriteKeys  = $normalized
        Provider      = [string] $Provider
        Window        = $Window
    }
    & $PreferencesWriter $document
    return $document
}

function Save-KapselFavorites {
    [CmdletBinding()]
    param(
        [object[]] $FavoriteKeys = @(),
        [object[]] $Applications = @(),
        [Parameter(Mandatory = $true)] [scriptblock] $PreferencesWriter
    )

    return Save-KapselPreferences -FavoriteKeys $FavoriteKeys -Applications $Applications -PreferencesWriter $PreferencesWriter
}

function Set-KapselFavorite {
    [CmdletBinding()]
    param(
        [object[]] $FavoriteKeys = @(),
        [object[]] $Applications = @(),
        [Parameter(Mandatory = $true)] [string] $Key,
        [Parameter(Mandatory = $true)] [bool] $IsFavorite,
        [AllowNull()] [string] $Provider = '',
        [AllowNull()] [object] $Window,
        [Parameter(Mandatory = $true)] [scriptblock] $PreferencesWriter
    )

    $updated = @(Set-KapselFavoriteKey -FavoriteKeys $FavoriteKeys -Key $Key -IsFavorite $IsFavorite -AvailableKeys @($Applications.Key))
    $document = Save-KapselPreferences -FavoriteKeys $updated -Applications $Applications -Provider $Provider -Window $Window -PreferencesWriter $PreferencesWriter
    return @($document.FavoriteKeys)
}

Export-ModuleMember -Function @(
    'Get-KapselPreferenceState',
    'Get-KapselFavorites',
    'Save-KapselPreferences',
    'Save-KapselFavorites',
    'Set-KapselFavorite'
)

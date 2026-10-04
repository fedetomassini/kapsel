# User-preference use cases. Storage is injected by the composition root.
Set-StrictMode -Version Latest

Import-Module (Join-Path (Split-Path -Parent $PSScriptRoot) 'Domain\UserPreferences.psm1') -Force

function Get-KapselFavorites {
    [CmdletBinding()]
    param(
        [object[]] $Applications = @(),
        [Parameter(Mandatory = $true)] [scriptblock] $PreferencesReader
    )

    $preferences = ConvertFrom-KapselPreferencesDocument -Document (& $PreferencesReader)
    return @(ConvertTo-KapselFavoriteKeys -FavoriteKeys $preferences.FavoriteKeys -AvailableKeys @($Applications.Key))
}

function Save-KapselFavorites {
    [CmdletBinding()]
    param(
        [object[]] $FavoriteKeys = @(),
        [object[]] $Applications = @(),
        [Parameter(Mandatory = $true)] [scriptblock] $PreferencesWriter
    )

    $normalized = @(ConvertTo-KapselFavoriteKeys -FavoriteKeys $FavoriteKeys -AvailableKeys @($Applications.Key))
    & $PreferencesWriter ([PSCustomObject] @{ SchemaVersion = 1; FavoriteKeys = $normalized })
    return $normalized
}

function Set-KapselFavorite {
    [CmdletBinding()]
    param(
        [object[]] $FavoriteKeys = @(),
        [object[]] $Applications = @(),
        [Parameter(Mandatory = $true)] [string] $Key,
        [Parameter(Mandatory = $true)] [bool] $IsFavorite,
        [Parameter(Mandatory = $true)] [scriptblock] $PreferencesWriter
    )

    $updated = @(Set-KapselFavoriteKey -FavoriteKeys $FavoriteKeys -Key $Key -IsFavorite $IsFavorite -AvailableKeys @($Applications.Key))
    return @(Save-KapselFavorites -FavoriteKeys $updated -Applications $Applications -PreferencesWriter $PreferencesWriter)
}

Export-ModuleMember -Function @('Get-KapselFavorites', 'Save-KapselFavorites', 'Set-KapselFavorite')

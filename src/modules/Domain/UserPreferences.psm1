# Pure user-preference rules. Persistence belongs to an infrastructure adapter.
Set-StrictMode -Version Latest

function ConvertFrom-KapselWindowState {
    [CmdletBinding()]
    param([AllowNull()] [object] $Window)

    # UI state is non-critical: malformed bounds are ignored instead of blocking favorites.
    if ($null -eq $Window) { return $null }
    foreach ($name in @('Left', 'Top', 'Width', 'Height')) {
        $property = $Window.PSObject.Properties[$name]
        if ($null -eq $property -or ($property.Value -isnot [int] -and $property.Value -isnot [long])) {
            return $null
        }
    }
    $left = [int] $Window.Left
    $top = [int] $Window.Top
    $width = [int] $Window.Width
    $height = [int] $Window.Height
    if ($width -lt 800 -or $width -gt 20000 -or $height -lt 600 -or $height -gt 20000) { return $null }
    if ($left -lt -20000 -or $left -gt 20000 -or $top -lt -20000 -or $top -gt 20000) { return $null }

    $maximized = $false
    $maximizedProperty = $Window.PSObject.Properties['Maximized']
    if ($null -ne $maximizedProperty) {
        if ($maximizedProperty.Value -isnot [bool]) { return $null }
        $maximized = [bool] $maximizedProperty.Value
    }

    return [PSCustomObject] @{
        Left      = $left
        Top       = $top
        Width     = $width
        Height    = $height
        Maximized = $maximized
    }
}

function ConvertFrom-KapselPreferencesDocument {
    [CmdletBinding()]
    param([Parameter(Mandatory = $true)] [AllowNull()] [object] $Document)

    if ($null -eq $Document -or $null -eq $Document.PSObject.Properties['FavoriteKeys']) {
        throw 'Preferences must contain a FavoriteKeys array.'
    }
    $version = $Document.PSObject.Properties['SchemaVersion']
    # Accept legacy favorites-only files and both supported schemas.
    if ($null -ne $version -and (($version.Value -isnot [int] -and $version.Value -isnot [long]) -or $version.Value -notin @(1, 2))) {
        throw "Unsupported preferences schema '$($version.Value)'. This app supports schemas 1 and 2."
    }
    if ($Document.FavoriteKeys -isnot [array] -or @($Document.FavoriteKeys | Where-Object { $_ -isnot [string] }).Count -gt 0) {
        throw 'FavoriteKeys must be an array of strings.'
    }

    $provider = ''
    $providerProperty = $Document.PSObject.Properties['Provider']
    if ($null -ne $providerProperty -and -not [string]::IsNullOrWhiteSpace([string] $providerProperty.Value)) {
        $candidate = ([string] $providerProperty.Value).Trim().ToLowerInvariant()
        if ($candidate -in @('winget', 'choco')) { $provider = $candidate }
    }

    $window = $null
    $windowProperty = $Document.PSObject.Properties['Window']
    if ($null -ne $windowProperty) {
        $window = ConvertFrom-KapselWindowState -Window $windowProperty.Value
    }

    return [PSCustomObject] @{
        SchemaVersion = 2
        FavoriteKeys  = @(ConvertTo-KapselFavoriteKeys -FavoriteKeys $Document.FavoriteKeys)
        Provider      = $provider
        Window        = $window
    }
}

function ConvertTo-KapselFavoriteKeys {
    [CmdletBinding()]
    param(
        [AllowNull()] [object[]] $FavoriteKeys = @(),
        [string[]] $AvailableKeys = @()
    )

    $available = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($key in @($AvailableKeys)) {
        if (-not [string]::IsNullOrWhiteSpace($key)) { [void] $available.Add($key.Trim()) }
    }

    $normalized = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($value in @($FavoriteKeys)) {
        $key = ([string] $value).Trim()
        if (-not [string]::IsNullOrWhiteSpace($key) -and ($available.Count -eq 0 -or $available.Contains($key))) {
            [void] $normalized.Add($key)
        }
    }

    return @($normalized | Sort-Object)
}

function Set-KapselFavoriteKey {
    [CmdletBinding()]
    param(
        [object[]] $FavoriteKeys = @(),
        [Parameter(Mandatory = $true)] [string] $Key,
        [Parameter(Mandatory = $true)] [bool] $IsFavorite,
        [string[]] $AvailableKeys = @()
    )

    $keyValue = $Key.Trim()
    if ([string]::IsNullOrWhiteSpace($keyValue)) { throw 'The favorite application key cannot be empty.' }
    if ($AvailableKeys.Count -gt 0 -and $keyValue -notin $AvailableKeys) {
        throw "Application '$keyValue' does not exist in the catalog."
    }

    $keys = @(ConvertTo-KapselFavoriteKeys -FavoriteKeys $FavoriteKeys -AvailableKeys $AvailableKeys)
    if ($IsFavorite) { $keys += $keyValue } else { $keys = @($keys | Where-Object { $_ -ine $keyValue }) }
    return @(ConvertTo-KapselFavoriteKeys -FavoriteKeys $keys -AvailableKeys $AvailableKeys)
}

Export-ModuleMember -Function @(
    'ConvertFrom-KapselPreferencesDocument',
    'ConvertFrom-KapselWindowState',
    'ConvertTo-KapselFavoriteKeys',
    'Set-KapselFavoriteKey'
)

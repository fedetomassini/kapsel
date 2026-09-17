# Pure user-preference rules. Persistence belongs to an infrastructure adapter.
Set-StrictMode -Version Latest

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

Export-ModuleMember -Function @('ConvertTo-KapselFavoriteKeys', 'Set-KapselFavoriteKey')

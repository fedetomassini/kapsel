# Pure application-catalog rules. This module has no filesystem, process, or UI dependencies.
Set-StrictMode -Version Latest

function Get-KapselCatalogProperty {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [object] $InputObject,

        [Parameter(Mandatory = $true)]
        [string] $Name,

        [object] $Default = $null
    )

    $property = $InputObject.PSObject.Properties[$Name]
    if ($null -eq $property) {
        return $Default
    }

    return $property.Value
}

function ConvertTo-KapselPackageIdentifier {
    [CmdletBinding()]
    param([AllowNull()] [object] $Value)

    if ($null -eq $Value) {
        return $null
    }

    $identifier = ([string] $Value).Trim()
    if ([string]::IsNullOrWhiteSpace($identifier) -or $identifier -ieq 'na') {
        return $null
    }

    return $identifier
}

function ConvertFrom-KapselCatalogDocument {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [object] $CatalogDocument
    )

    $applications = New-Object System.Collections.Generic.List[object]
    $keys = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase)

    foreach ($entry in @($CatalogDocument.PSObject.Properties)) {
        $key = ([string] $entry.Name).Trim()
        if ([string]::IsNullOrWhiteSpace($key)) {
            throw 'The application catalog contains an empty key.'
        }

        if (-not $keys.Add($key)) {
            throw "The application catalog contains a duplicate key: $key"
        }

        $value = $entry.Value
        if ($null -eq $value) {
            throw "Catalog entry '$key' is empty."
        }

        $name = ([string] (Get-KapselCatalogProperty -InputObject $value -Name 'content' -Default $key)).Trim()
        $category = ([string] (Get-KapselCatalogProperty -InputObject $value -Name 'category' -Default 'Uncategorized')).Trim()
        if ([string]::IsNullOrWhiteSpace($name)) {
            throw "Catalog entry '$key' does not define a display name."
        }
        if ([string]::IsNullOrWhiteSpace($category)) {
            $category = 'Uncategorized'
        }

        $wingetId = ConvertTo-KapselPackageIdentifier -Value (Get-KapselCatalogProperty -InputObject $value -Name 'winget')
        $chocoId = ConvertTo-KapselPackageIdentifier -Value (Get-KapselCatalogProperty -InputObject $value -Name 'choco')
        foreach ($packageIdentifier in @($wingetId, $chocoId)) {
            if ($null -ne $packageIdentifier -and $packageIdentifier -notmatch '^[A-Za-z0-9][A-Za-z0-9._+\-]*$') {
                throw "Catalog entry '$key' contains an invalid package identifier: $packageIdentifier"
            }
        }

        $link = ([string] (Get-KapselCatalogProperty -InputObject $value -Name 'link' -Default '')).Trim()
        if (-not [string]::IsNullOrWhiteSpace($link)) {
            $linkUri = $null
            $isValidLink = [Uri]::TryCreate($link, [UriKind]::Absolute, [ref] $linkUri) -and
                $linkUri.Scheme -in @('http', 'https')
            if (-not $isValidLink) {
                throw "Catalog entry '$key' contains an invalid official link: $link"
            }
        }

        $foss = Get-KapselCatalogProperty -InputObject $value -Name 'foss' -Default $false
        if ($foss -isnot [bool]) {
            throw "Catalog entry '$key' must define foss as a boolean."
        }
        $preferredProvider = if ($wingetId) { 'winget' } elseif ($chocoId) { 'choco' } else { 'unavailable' }

        [void] $applications.Add([PSCustomObject] @{
            Key               = $key
            Name              = $name
            Category          = $category
            Description       = [string] (Get-KapselCatalogProperty -InputObject $value -Name 'description' -Default '')
            Link              = $link
            WingetId          = $wingetId
            ChocoId           = $chocoId
            PreferredProvider = $preferredProvider
            Foss              = [bool] $foss
        })
    }

    return $applications.ToArray()
}

function Test-KapselTextContains {
    param(
        [AllowNull()] [object] $Value,
        [Parameter(Mandatory = $true)] [string] $Search
    )

    if ($null -eq $Value) {
        return $false
    }

    return ([string] $Value).IndexOf($Search, [System.StringComparison]::OrdinalIgnoreCase) -ge 0
}

function Search-KapselApplicationCatalog {
    [CmdletBinding()]
    param(
        [object[]] $Applications = @(),
        [string] $Search,
        [string] $Category = 'All',
        [switch] $FossOnly
    )

    $searchText = if ($null -eq $Search) { '' } else { $Search.Trim() }
    $items = @($Applications)

    if (-not [string]::IsNullOrWhiteSpace($searchText)) {
        $items = @($items | Where-Object {
            (Test-KapselTextContains -Value $_.Name -Search $searchText) -or
            (Test-KapselTextContains -Value $_.Key -Search $searchText) -or
            (Test-KapselTextContains -Value $_.Category -Search $searchText) -or
            (Test-KapselTextContains -Value $_.Description -Search $searchText) -or
            (Test-KapselTextContains -Value $_.WingetId -Search $searchText) -or
            (Test-KapselTextContains -Value $_.ChocoId -Search $searchText)
        })
    }

    if (-not [string]::IsNullOrWhiteSpace($Category) -and $Category -ne 'All') {
        $items = @($items | Where-Object { $_.Category -eq $Category })
    }

    if ($FossOnly) {
        $items = @($items | Where-Object { $_.Foss -eq $true })
    }

    return $items
}

function Get-KapselApplicationCategories {
    [CmdletBinding()]
    param([object[]] $Applications = @())

    return @('All') + @(
        $Applications |
            Select-Object -ExpandProperty Category -Unique |
            Sort-Object
    )
}

function Test-KapselApplicationProviderSupport {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)] [object] $Application,
        [Parameter(Mandatory = $true)]
        [ValidateSet('winget', 'choco')]
        [string] $Provider
    )

    $identifier = if ($Provider -eq 'winget') { $Application.WingetId } else { $Application.ChocoId }
    return -not [string]::IsNullOrWhiteSpace([string] $identifier)
}

Export-ModuleMember -Function @(
    'ConvertFrom-KapselCatalogDocument',
    'Search-KapselApplicationCatalog',
    'Get-KapselApplicationCategories',
    'Test-KapselApplicationProviderSupport'
)

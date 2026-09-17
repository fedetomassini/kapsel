# JSON adapter for user preferences stored outside the installation directory.
Set-StrictMode -Version Latest

function Get-KapselPreferencesPath {
    [CmdletBinding()]
    param()

    $dataRoot = if (-not [string]::IsNullOrWhiteSpace($env:KAPSEL_DATA_DIRECTORY)) {
        $env:KAPSEL_DATA_DIRECTORY
    }
    else {
        Join-Path ([Environment]::GetFolderPath([Environment+SpecialFolder]::LocalApplicationData)) 'Kapsel'
    }
    if ([string]::IsNullOrWhiteSpace($dataRoot)) { throw 'The Kapsel data directory could not be resolved.' }
    return Join-Path $dataRoot 'preferences.json'
}

function Read-KapselUserPreferences {
    [CmdletBinding()]
    param([string] $Path = (Get-KapselPreferencesPath))

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        return [PSCustomObject] @{ SchemaVersion = 1; FavoriteKeys = @() }
    }
    try {
        return Get-Content -LiteralPath $Path -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
    }
    catch {
        throw "User preferences could not be read from '$Path': $($_.Exception.Message)"
    }
}

function Write-KapselUserPreferences {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)] [object] $Preferences,
        [string] $Path = (Get-KapselPreferencesPath)
    )

    $directory = Split-Path -Parent $Path
    if ([string]::IsNullOrWhiteSpace($directory)) { throw 'The preferences path must include a directory.' }
    New-Item -ItemType Directory -Path $directory -Force | Out-Null
    $temporaryPath = Join-Path $directory ('.preferences-{0}.tmp' -f [Guid]::NewGuid().ToString('N'))
    try {
        $Preferences | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $temporaryPath -Encoding UTF8 -ErrorAction Stop
        Move-Item -LiteralPath $temporaryPath -Destination $Path -Force -ErrorAction Stop
    }
    finally {
        if (Test-Path -LiteralPath $temporaryPath) { Remove-Item -LiteralPath $temporaryPath -Force }
    }
}

Export-ModuleMember -Function @('Get-KapselPreferencesPath', 'Read-KapselUserPreferences', 'Write-KapselUserPreferences')

# Diagnostics file access: package logs and user-selected report exports.
Set-StrictMode -Version Latest

function Get-KapselLogDirectory {
    [CmdletBinding()]
    param([string] $BaseDirectory)

    $root = if ([string]::IsNullOrWhiteSpace($BaseDirectory)) {
        Join-Path ([Environment]::GetFolderPath([Environment+SpecialFolder]::LocalApplicationData)) 'Kapsel'
    }
    else {
        $BaseDirectory
    }
    if ([string]::IsNullOrWhiteSpace($root)) { throw 'The Kapsel data directory could not be resolved.' }
    return Join-Path $root 'Logs'
}

function Get-KapselPackageLogFiles {
    [CmdletBinding()]
    param(
        [string] $Directory = (Get-KapselLogDirectory),
        [ValidateRange(1, 200)] [int] $Limit = 20
    )

    if (-not (Test-Path -LiteralPath $Directory -PathType Container)) { return @() }
    return @(Get-ChildItem -LiteralPath $Directory -File -Filter '*.log' -ErrorAction SilentlyContinue |
        Sort-Object -Property LastWriteTime -Descending |
        Select-Object -First $Limit)
}

function Remove-KapselExpiredPackageLogs {
    [CmdletBinding()]
    param(
        [string] $Directory = (Get-KapselLogDirectory),
        [ValidateRange(1, 3650)] [int] $RetentionDays = 30,
        [DateTime] $Now = (Get-Date)
    )

    if (-not (Test-Path -LiteralPath $Directory -PathType Container)) { return 0 }
    $cutoff = $Now.AddDays(-$RetentionDays)
    $removed = 0
    foreach ($file in @(Get-ChildItem -LiteralPath $Directory -File -Filter '*.log' -ErrorAction SilentlyContinue)) {
        if ($file.LastWriteTime -ge $cutoff) { continue }
        try {
            Remove-Item -LiteralPath $file.FullName -Force -ErrorAction Stop
            $removed++
        }
        catch {
            # A provider may still hold the file open; leave it for the next run.
            Write-Verbose "Could not remove expired package log: $($file.FullName)"
        }
    }
    return $removed
}

function Write-KapselDiagnosticsFile {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)] [string] $Path,
        [Parameter(Mandatory = $true)] [AllowEmptyString()] [string] $Text
    )

    $resolved = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Path)
    $directory = Split-Path -Parent $resolved
    if ([string]::IsNullOrWhiteSpace($directory)) { throw 'The diagnostics path must include a directory.' }
    New-Item -ItemType Directory -Path $directory -Force | Out-Null

    $temporary = Join-Path $directory ('.kapsel-diagnostics-{0}.tmp' -f [Guid]::NewGuid().ToString('N'))
    $encoding = New-Object System.Text.UTF8Encoding($false)
    try {
        [System.IO.File]::WriteAllText($temporary, $Text, $encoding)
        Move-Item -LiteralPath $temporary -Destination $resolved -Force -ErrorAction Stop
    }
    finally {
        if (Test-Path -LiteralPath $temporary) { Remove-Item -LiteralPath $temporary -Force }
    }
    return $resolved
}

Export-ModuleMember -Function @(
    'Get-KapselLogDirectory',
    'Get-KapselPackageLogFiles',
    'Remove-KapselExpiredPackageLogs',
    'Write-KapselDiagnosticsFile'
)

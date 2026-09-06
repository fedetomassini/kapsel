# winget and Chocolatey process adapter.
Set-StrictMode -Version Latest

function Test-KapselCommandAvailable {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string] $Name
    )

    return $null -ne (Get-Command -Name $Name -ErrorAction SilentlyContinue)
}

function Get-KapselPackageProviderStatus {
    [CmdletBinding()]
    param()

    return [PSCustomObject] @{
        WingetAvailable = Test-KapselCommandAvailable -Name 'winget'
        ChocoAvailable  = Test-KapselCommandAvailable -Name 'choco'
    }
}

function Invoke-KapselPackageProcess {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [object] $Command
    )

    if ([string]::IsNullOrWhiteSpace([string] $Command.Executable)) {
        throw 'The package command does not define an executable.'
    }

    $logDirectory = Join-Path ([Environment]::GetFolderPath('LocalApplicationData')) 'Kapsel\Logs'
    [void] (New-Item -ItemType Directory -Path $logDirectory -Force)
    $logName = '{0}-{1}' -f (Get-Date -Format 'yyyyMMdd-HHmmss'), [Guid]::NewGuid().ToString('N')
    $outputPath = Join-Path $logDirectory "$logName.stdout.log"
    $errorPath = Join-Path $logDirectory "$logName.stderr.log"
    $startParameters = @{
        FilePath     = [string] $Command.Executable
        ArgumentList = [string[]] $Command.Arguments
        Wait         = $true
        PassThru     = $true
        WindowStyle  = 'Hidden'
        RedirectStandardOutput = $outputPath
        RedirectStandardError = $errorPath
        ErrorAction  = 'Stop'
    }
    $process = $null
    try {
        $process = Start-Process @startParameters
        $outputText = [string] (Get-Content -LiteralPath $outputPath -Raw -Encoding UTF8)
        $errorText = [string] (Get-Content -LiteralPath $errorPath -Raw -Encoding UTF8)
        # Strip terminal color/cursor sequences and spinner-only lines for readable Activity entries.
        $diagnostics = (($outputText, $errorText) -join [Environment]::NewLine) -replace '\x1B\[[0-?]*[ -/]*[@-~]', ''
        $lines = @($diagnostics -split '\r\n|\r|\n' | Where-Object { -not [string]::IsNullOrWhiteSpace($_) -and $_ -notmatch '^\s*[-\\|/]\s*$' })
        return [PSCustomObject] @{
            ExitCode = [int] $process.ExitCode
            Diagnostics = ($lines -join [Environment]::NewLine).Trim()
            LogPaths = @($outputPath, $errorPath)
        }
    }
    finally {
        if ($null -ne $process) { $process.Dispose() }
    }
}

Export-ModuleMember -Function @(
    'Test-KapselCommandAvailable',
    'Get-KapselPackageProviderStatus',
    'Invoke-KapselPackageProcess'
)

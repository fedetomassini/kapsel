# Queries provider inventories without affecting package operation logs or UI state.
Set-StrictMode -Version Latest

function Invoke-KapselInventoryProcess {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)] [string] $Executable,
        [Parameter(Mandatory = $true)] [string] $Arguments,
        [ValidateRange(1, 600)] [int] $TimeoutSeconds = 90,
        [System.Threading.CancellationToken] $CancellationToken = [System.Threading.CancellationToken]::None
    )

    if ($CancellationToken.IsCancellationRequested) { throw [System.OperationCanceledException]::new("$Executable inventory query was cancelled.") }
    $startInfo = New-Object System.Diagnostics.ProcessStartInfo
    $startInfo.FileName = $Executable
    $startInfo.Arguments = $Arguments
    $startInfo.UseShellExecute = $false
    $startInfo.CreateNoWindow = $true
    $startInfo.RedirectStandardOutput = $true
    $startInfo.RedirectStandardError = $true
    $process = New-Object System.Diagnostics.Process
    $process.StartInfo = $startInfo
    try {
        if (-not $process.Start()) { throw "Could not start $Executable." }
        $output = $process.StandardOutput.ReadToEndAsync()
        $errors = $process.StandardError.ReadToEndAsync()
        $deadline = [DateTime]::UtcNow.AddSeconds($TimeoutSeconds)
        while (-not $process.WaitForExit(250)) {
            if ($CancellationToken.IsCancellationRequested) {
                $process.Kill()
                throw [System.OperationCanceledException]::new("$Executable inventory query was cancelled.")
            }
            if ([DateTime]::UtcNow -ge $deadline) {
                $process.Kill()
                throw [System.TimeoutException]::new("$Executable inventory query timed out after $TimeoutSeconds seconds.")
            }
        }
        if (-not [System.Threading.Tasks.Task]::WaitAll(@($output, $errors), 5000)) {
            throw [System.TimeoutException]::new("$Executable exited but its redirected output did not close within 5 seconds.")
        }
        return [PSCustomObject] @{
            ExitCode = [int] $process.ExitCode
            Output = [string] $output.Result
            Error = [string] $errors.Result
        }
    }
    finally {
        $process.Dispose()
    }
}

function Get-KapselProviderDiagnostics {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)] [ValidateSet('winget', 'choco')] [string] $Provider,
        [System.Threading.CancellationToken] $CancellationToken = [System.Threading.CancellationToken]::None
    )

    $command = Get-Command -Name $Provider -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
    $diagnostics = [PSCustomObject] @{ Provider = $Provider; Available = $null -ne $command; ExecutablePath = ''; Version = ''; Supported = $false; Message = '' }
    if ($null -eq $command) {
        $diagnostics.Message = "$Provider executable was not found on PATH. Install or repair the provider, then reopen Kapsel."
        return $diagnostics
    }
    $diagnostics.ExecutablePath = $command.Path
    try {
        $result = Invoke-KapselInventoryProcess -Executable $command.Path -Arguments '--version' -TimeoutSeconds 5 -CancellationToken $CancellationToken
        if ($result.ExitCode -ne 0 -or $result.Output -notmatch '(?m)^\s*v?(\d+\.\d+(?:\.\d+)?)\b') {
            $diagnostics.Message = "$Provider version could not be determined (exit $($result.ExitCode)): $($result.Error) $($result.Output)"
            return $diagnostics
        }
        $diagnostics.Version = $matches[1]
        $version = [version] $diagnostics.Version
        if ($Provider -eq 'choco') {
            # Before Chocolatey 2, `list` without --local-only could return remote packages.
            $diagnostics.Supported = $version.Major -ge 2
            if (-not $diagnostics.Supported) { $diagnostics.Message = "Chocolatey $version is unsupported for inventory. Update to Chocolatey 2 or newer; local list semantics changed in version 2." }
        }
        else {
            $help = Invoke-KapselInventoryProcess -Executable $command.Path -Arguments 'list --help' -TimeoutSeconds 5 -CancellationToken $CancellationToken
            # Flags are invariant across localized help; avoid guessing compatibility from version alone.
            $diagnostics.Supported = $help.ExitCode -eq 0 -and $help.Output.Contains('--upgrade-available') -and $help.Output.Contains('--disable-interactivity')
            if (-not $diagnostics.Supported) { $diagnostics.Message = "winget $version does not expose the inventory options Kapsel needs. Update App Installer. $($help.Error)" }
        }
    }
    catch {
        if ($CancellationToken.IsCancellationRequested) { throw }
        $diagnostics.Message = "$Provider diagnostics failed: $($_.Exception.Message)"
    }
    return $diagnostics
}

function Get-KapselInventoryFailureMessage {
    [CmdletBinding()]
    param([string] $Provider, [string] $Operation, [object] $Result)

    $hexCode = ([uint32] ([long] $Result.ExitCode -band 4294967295)).ToString('X8')
    # Numeric winget HRESULTs remain reliable when console output is localized.
    # https://github.com/microsoft/winget-cli/blob/master/src/AppInstallerSharedLib/Public/AppInstallerErrors.h
    $reason = if ($Provider -eq 'winget') {
        switch ($hexCode) {
            { $_ -in @('80070005', '8A150019') } { 'Permission denied or administrator privileges required.' }
            { $_ -in @('8A15000B', '8A15000F', '8A150012', '8A150015', '8A150045', '8A15004B', '8A150046') } { 'Provider sources unavailable or agreements not accepted. Check source configuration and connectivity.' }
            { $_ -in @('8A150002', '8A150059') } { 'Provider arguments are unsupported. Update the provider and retry.' }
            default { 'The provider could not complete this query.' }
        }
    }
    else { 'The provider could not complete this query.' }
    return "$Provider $Operation failed (exit $($Result.ExitCode), 0x$hexCode). $reason $($Result.Error) $($Result.Output)".Trim()
}

function Get-KapselProviderInventory {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)] [ValidateSet('winget', 'choco')] [string] $Provider,
        [System.Threading.CancellationToken] $CancellationToken = [System.Threading.CancellationToken]::None
    )

    $diagnostics = Get-KapselProviderDiagnostics -Provider $Provider -CancellationToken $CancellationToken
    if (-not $diagnostics.Supported) { throw "$($diagnostics.Message) Executable: $($diagnostics.ExecutablePath)" }
    $executable = $diagnostics.ExecutablePath
    if ($Provider -eq 'choco') {
        $installed = Invoke-KapselInventoryProcess -Executable $executable -Arguments 'list --limit-output --no-color' -CancellationToken $CancellationToken
        if ($installed.ExitCode -ne 0) { throw (Get-KapselInventoryFailureMessage -Provider $Provider -Operation 'list' -Result $installed) }
        $updates = try {
            Invoke-KapselInventoryProcess -Executable $executable -Arguments 'outdated --limit-output --no-color' -CancellationToken $CancellationToken
        }
        catch {
            if ($CancellationToken.IsCancellationRequested) { throw }
            [PSCustomObject] @{ ExitCode = -1; Output = ''; Error = $_.Exception.Message }
        }
        return [PSCustomObject] @{
            InstalledOutput = $installed.Output
            UpdateOutput = if ($updates.ExitCode -in @(0, 2)) { $updates.Output } else { '' }
            UpdatesChecked = $updates.ExitCode -in @(0, 2)
            Warning = if ($updates.ExitCode -in @(0, 2)) { '' } else { Get-KapselInventoryFailureMessage -Provider $Provider -Operation 'update check' -Result $updates }
            Diagnostics = $diagnostics
        }
    }

    $exportPath = Join-Path ([System.IO.Path]::GetTempPath()) ("kapsel-inventory-$([Guid]::NewGuid().ToString('N')).json")
    try {
        $export = Invoke-KapselInventoryProcess -Executable $executable -Arguments "export --output `"$exportPath`" --include-versions --accept-source-agreements --disable-interactivity" -CancellationToken $CancellationToken
        if ($export.ExitCode -ne 0 -or -not (Test-Path -LiteralPath $exportPath -PathType Leaf)) {
            throw (Get-KapselInventoryFailureMessage -Provider $Provider -Operation 'export' -Result $export)
        }
        try {
            $document = Get-Content -LiteralPath $exportPath -Raw -Encoding UTF8 | ConvertFrom-Json -ErrorAction Stop
            if ($null -eq $document -or $null -eq $document.PSObject.Properties['Sources']) { throw 'Missing Sources in exported inventory.' }
        }
        catch { throw "winget $($diagnostics.Version) inventory JSON could not be parsed: $($_.Exception.Message)" }
        $updates = try {
            Invoke-KapselInventoryProcess -Executable $executable -Arguments 'list --upgrade-available --accept-source-agreements --disable-interactivity' -CancellationToken $CancellationToken
        }
        catch {
            if ($CancellationToken.IsCancellationRequested) { throw }
            [PSCustomObject] @{ ExitCode = -1; Output = ''; Error = $_.Exception.Message }
        }
        return [PSCustomObject] @{
            InstalledDocument = $document
            UpdateOutput = if ($updates.ExitCode -eq 0) { $updates.Output } else { '' }
            UpdatesChecked = $updates.ExitCode -in @(0, -1978335212)
            Warning = if ($updates.ExitCode -in @(0, -1978335212)) { '' } else { Get-KapselInventoryFailureMessage -Provider $Provider -Operation 'update check' -Result $updates }
            Diagnostics = $diagnostics
        }
    }
    finally {
        Remove-Item -LiteralPath $exportPath -Force -ErrorAction SilentlyContinue
    }
}

Export-ModuleMember -Function @('Invoke-KapselInventoryProcess', 'Get-KapselProviderDiagnostics', 'Get-KapselProviderInventory')

# Queries provider inventories without affecting package operation logs or UI state.
Set-StrictMode -Version Latest

function Invoke-KapselInventoryProcess {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)] [string] $Executable,
        [Parameter(Mandatory = $true)] [string] $Arguments,
        [int] $TimeoutSeconds = 90,
        [System.Threading.CancellationToken] $CancellationToken = [System.Threading.CancellationToken]::None
    )

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
                throw "$Executable inventory query was cancelled."
            }
            if ([DateTime]::UtcNow -ge $deadline) {
                $process.Kill()
                throw "$Executable inventory query timed out after $TimeoutSeconds seconds."
            }
        }
        [void] [System.Threading.Tasks.Task]::WaitAll(@($output, $errors), 5000)
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

function Get-KapselProviderInventory {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)] [ValidateSet('winget', 'choco')] [string] $Provider,
        [System.Threading.CancellationToken] $CancellationToken = [System.Threading.CancellationToken]::None
    )

    if ($Provider -eq 'choco') {
        $installed = Invoke-KapselInventoryProcess -Executable 'choco' -Arguments 'list --limit-output --no-color' -CancellationToken $CancellationToken
        if ($installed.ExitCode -ne 0) { throw "Chocolatey list failed: $($installed.Error)" }
        $updates = try {
            Invoke-KapselInventoryProcess -Executable 'choco' -Arguments 'outdated --limit-output --no-color' -CancellationToken $CancellationToken
        }
        catch {
            if ($CancellationToken.IsCancellationRequested) { throw }
            [PSCustomObject] @{ ExitCode = -1; Output = ''; Error = $_.Exception.Message }
        }
        return [PSCustomObject] @{
            InstalledOutput = $installed.Output
            UpdateOutput = if ($updates.ExitCode -in @(0, 2)) { $updates.Output } else { '' }
            UpdatesChecked = $updates.ExitCode -in @(0, 2)
            Warning = if ($updates.ExitCode -in @(0, 2)) { '' } else { "Chocolatey update check failed: $($updates.Error)" }
        }
    }

    $exportPath = Join-Path ([System.IO.Path]::GetTempPath()) ("kapsel-inventory-$([Guid]::NewGuid().ToString('N')).json")
    try {
        $export = Invoke-KapselInventoryProcess -Executable 'winget' -Arguments "export --output `"$exportPath`" --include-versions --accept-source-agreements --disable-interactivity" -CancellationToken $CancellationToken
        if ($export.ExitCode -ne 0 -or -not (Test-Path -LiteralPath $exportPath -PathType Leaf)) {
            throw "winget export failed: $($export.Error) $($export.Output)"
        }
        $document = Get-Content -LiteralPath $exportPath -Raw -Encoding UTF8 | ConvertFrom-Json -ErrorAction Stop
        $updates = try {
            Invoke-KapselInventoryProcess -Executable 'winget' -Arguments 'list --upgrade-available --accept-source-agreements --disable-interactivity' -CancellationToken $CancellationToken
        }
        catch {
            if ($CancellationToken.IsCancellationRequested) { throw }
            [PSCustomObject] @{ ExitCode = -1; Output = ''; Error = $_.Exception.Message }
        }
        return [PSCustomObject] @{
            InstalledDocument = $document
            UpdateOutput = if ($updates.ExitCode -eq 0) { $updates.Output } else { '' }
            UpdatesChecked = $updates.ExitCode -eq 0
            Warning = if ($updates.ExitCode -eq 0) { '' } else { "winget update check failed: $($updates.Error)" }
        }
    }
    finally {
        Remove-Item -LiteralPath $exportPath -Force -ErrorAction SilentlyContinue
    }
}

Export-ModuleMember -Function @('Invoke-KapselInventoryProcess', 'Get-KapselProviderInventory')

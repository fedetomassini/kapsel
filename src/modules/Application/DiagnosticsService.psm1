# Builds a redacted, local-only support report. Callers inject runtime state and log metadata.
Set-StrictMode -Version Latest

Import-Module (Join-Path (Split-Path -Parent $PSScriptRoot) 'Domain\Diagnostics.psm1') -Force

function Get-KapselDiagnosticValue {
    [CmdletBinding()]
    param(
        [AllowNull()] [object] $InputObject,
        [Parameter(Mandatory = $true)] [string] $Name,
        [object] $Default = $null
    )

    if ($null -eq $InputObject) { return $Default }
    $property = $InputObject.PSObject.Properties[$Name]
    if ($null -eq $property) { return $Default }
    return $property.Value
}

function Get-KapselDiagnosticsFileName {
    [CmdletBinding()]
    param([DateTime] $GeneratedAt = (Get-Date))

    return 'Kapsel-diagnostics-{0}.txt' -f $GeneratedAt.ToString('yyyyMMdd-HHmmss')
}

function New-KapselDiagnosticsReport {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)] [object] $Metadata,
        [AllowNull()] [object] $ProviderStatus,
        [AllowNull()] [object] $InventoryDiagnostics,
        [AllowNull()] [object] $Inventory,
        [AllowNull()] [object] $Operation,
        [object[]] $LogFiles = @(),
        [string] $DataDirectory = '',
        [string] $LogDirectory = '',
        [DateTime] $GeneratedAt = (Get-Date)
    )

    $lines = New-Object System.Collections.Generic.List[string]
    $lines.Add('Kapsel diagnostics')
    $lines.Add("Generated: $($GeneratedAt.ToString('yyyy-MM-dd HH:mm:ss zzz'))")
    $lines.Add("Product: $($Metadata.Name) $($Metadata.Version)")
    $is64Bit = [Environment]::Is64BitOperatingSystem
    $lines.Add("Runtime: $([Environment]::OSVersion.VersionString) | PowerShell $($PSVersionTable.PSVersion) | 64-bit OS: $is64Bit")
    $lines.Add("Data directory: $DataDirectory")
    $lines.Add("Log directory: $LogDirectory")
    $lines.Add('')

    $lines.Add('Providers:')
    foreach ($provider in @('winget', 'choco')) {
        $propertyName = if ($provider -eq 'winget') { 'WingetAvailable' } else { 'ChocoAvailable' }
        $available = [bool] (Get-KapselDiagnosticValue -InputObject $ProviderStatus -Name $propertyName -Default $false)
        $state = if ($available) { 'available' } else { 'missing' }
        $diagnostic = if ($null -ne $InventoryDiagnostics) { $InventoryDiagnostics[$provider] } else { $null }
        if ($null -ne $diagnostic) {
            $supported = [bool] (Get-KapselDiagnosticValue -InputObject $diagnostic -Name 'Supported' -Default $false)
            $lines.Add(('  {0}: {1} | version {2} | {3} | supported: {4}' -f $provider, $state,
                (Get-KapselDiagnosticValue -InputObject $diagnostic -Name 'Version' -Default 'unknown'),
                (Get-KapselDiagnosticValue -InputObject $diagnostic -Name 'ExecutablePath' -Default 'unknown'),
                $supported))
        }
        else {
            $lines.Add("  ${provider}: $state | diagnostics not collected")
        }
    }
    $lines.Add('')

    $lines.Add('Inventory:')
    if ($null -eq $Inventory) {
        $lines.Add('  not initialized')
    }
    else {
        $snapshot = Get-KapselDiagnosticValue -InputObject $Inventory -Name 'Snapshot'
        $checkedAt = Get-KapselDiagnosticValue -InputObject $Inventory -Name 'CheckedAt'
        $checkedText = if ($checkedAt -is [DateTime]) { $checkedAt.ToLocalTime().ToString('yyyy-MM-dd HH:mm:ss') } else { 'never' }
        $lines.Add(('  status={0} checked={1} provider={2} installed={3} updates={4} updatesChecked={5}' -f
            (Get-KapselDiagnosticValue -InputObject $Inventory -Name 'Status' -Default 'unknown'),
            $checkedText,
            (Get-KapselDiagnosticValue -InputObject $snapshot -Name 'Provider' -Default 'unknown'),
            (Get-KapselDiagnosticValue -InputObject $snapshot -Name 'InstalledCount' -Default 0),
            (Get-KapselDiagnosticValue -InputObject $snapshot -Name 'UpdateCount' -Default 0),
            (Get-KapselDiagnosticValue -InputObject $snapshot -Name 'UpdatesChecked' -Default $false)))
    }
    $lines.Add('')

    $lines.Add('Last batch:')
    if ($null -eq $Operation -or [int] (Get-KapselDiagnosticValue -InputObject $Operation -Name 'Total' -Default 0) -eq 0) {
        $lines.Add('  none in this session')
    }
    else {
        $lines.Add(('  action={0} provider={1} total={2} completed={3} succeeded={4} unchanged={5} restartRequired={6} failed={7} cancelled={8}' -f
            (Get-KapselDiagnosticValue -InputObject $Operation -Name 'Action' -Default 'unknown'),
            (Get-KapselDiagnosticValue -InputObject $Operation -Name 'Provider' -Default 'unknown'),
            (Get-KapselDiagnosticValue -InputObject $Operation -Name 'Total' -Default 0),
            (Get-KapselDiagnosticValue -InputObject $Operation -Name 'Completed' -Default 0),
            (Get-KapselDiagnosticValue -InputObject $Operation -Name 'Succeeded' -Default 0),
            (Get-KapselDiagnosticValue -InputObject $Operation -Name 'Unchanged' -Default 0),
            (Get-KapselDiagnosticValue -InputObject $Operation -Name 'RestartRequired' -Default 0),
            (Get-KapselDiagnosticValue -InputObject $Operation -Name 'Failed' -Default 0),
            (Get-KapselDiagnosticValue -InputObject $Operation -Name 'Cancelled' -Default 0)))
        foreach ($item in @(Get-KapselDiagnosticValue -InputObject $Operation -Name 'RestartItems' -Default @())) {
            $name = Get-KapselDiagnosticValue -InputObject $item -Name 'Name' -Default ([string] $item)
            $lines.Add("  restart required: $name")
        }
        foreach ($item in @(Get-KapselDiagnosticValue -InputObject $Operation -Name 'FailedItems' -Default @())) {
            $name = Get-KapselDiagnosticValue -InputObject $item -Name 'Name' -Default ([string] $item)
            $lines.Add("  failed: $name")
        }
    }
    $lines.Add('')

    $lines.Add('Package logs (newest first; retained 30 days):')
    if (@($LogFiles).Count -eq 0) {
        $lines.Add('  none')
    }
    else {
        foreach ($file in @($LogFiles)) {
            $name = Get-KapselDiagnosticValue -InputObject $file -Name 'Name' -Default 'unknown'
            $length = Get-KapselDiagnosticValue -InputObject $file -Name 'Length' -Default 0
            $lastWrite = Get-KapselDiagnosticValue -InputObject $file -Name 'LastWriteTime' -Default $null
            $lastWriteText = if ($lastWrite -is [DateTime]) { $lastWrite.ToLocalTime().ToString('yyyy-MM-dd HH:mm:ss') } else { 'unknown' }
            $lines.Add("  $name | $length bytes | $lastWriteText")
        }
    }
    $lines.Add('')
    $lines.Add('This report contains no package output or preference contents. Local paths and account names are redacted.')

    return Get-KapselRedactedText -Text ($lines -join [Environment]::NewLine)
}

Export-ModuleMember -Function @(
    'Get-KapselDiagnosticsFileName',
    'New-KapselDiagnosticsReport'
)

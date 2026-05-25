# Application catalog and package-manager operations.
# This module reads src/applications.json and exposes safe, testable objects for the UI.
Set-StrictMode -Version Latest

function Get-KapselApplicationsPath {
    [CmdletBinding()]
    param()

    return (Join-Path (Split-Path -Parent $PSScriptRoot) 'applications.json')
}

# Tests if a command is available on the system by trying to get its command info.
function Test-KapselCommandAvailable {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string] $Name
    )

    return $null -ne (Get-Command -Name $Name -ErrorAction SilentlyContinue)
}

function Get-KapselPackageManagerStatus {
    [CmdletBinding()]
    param()

    return [PSCustomObject] @{
        WingetAvailable = Test-KapselCommandAvailable -Name 'winget'
        ChocoAvailable  = Test-KapselCommandAvailable -Name 'choco'
    }
}

function ConvertTo-KapselPackageValue {
    param([object] $Value)

    if ($null -eq $Value) {
        return $null
    }

    $text = ([string] $Value).Trim()
    if ([string]::IsNullOrWhiteSpace($text) -or $text -ieq 'na') {
        return $null
    }

    return $text
}

function Get-KapselJsonPropertyValue {
    param(
        [Parameter(Mandatory = $true)]
        [object] $InputObject,

        [Parameter(Mandatory = $true)]
        [string] $Name,

        [Parameter(Mandatory = $false)]
        [object] $Default = $null
    )

    $property = $InputObject.PSObject.Properties[$Name]
    if ($null -eq $property) {
        return $Default
    }

    return $property.Value
}

# Reads the application catalog from the JSON file and returns a list of application objects with normalized properties.
function Get-KapselApplicationCatalog {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [string] $Path = (Get-KapselApplicationsPath)
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        throw "Application catalog not found: $Path"
    }

    $raw = Get-Content -LiteralPath $Path -Raw -ErrorAction Stop
    $catalog = $raw | ConvertFrom-Json

    foreach ($entry in $catalog.PSObject.Properties) {
        $value = $entry.Value
        $winget = ConvertTo-KapselPackageValue -Value (Get-KapselJsonPropertyValue -InputObject $value -Name 'winget')
        $choco = ConvertTo-KapselPackageValue -Value (Get-KapselJsonPropertyValue -InputObject $value -Name 'choco')
        $provider = if ($winget) { 'winget' } elseif ($choco) { 'choco' } else { 'unavailable' }

        [PSCustomObject] @{
            Selected    = $false
            Key         = $entry.Name
            Name        = [string] (Get-KapselJsonPropertyValue -InputObject $value -Name 'content' -Default $entry.Name)
            Category    = [string] (Get-KapselJsonPropertyValue -InputObject $value -Name 'category' -Default 'Uncategorized')
            Description = [string] (Get-KapselJsonPropertyValue -InputObject $value -Name 'description' -Default '')
            Link        = [string] (Get-KapselJsonPropertyValue -InputObject $value -Name 'link' -Default '')
            WingetId    = $winget
            ChocoId     = $choco
            Provider    = $provider
            Foss        = [bool] (Get-KapselJsonPropertyValue -InputObject $value -Name 'foss' -Default $false)
        }
    }
}

# Filters the application catalog based on search text, category, and FOSS preference.
function Search-KapselApplicationCatalog {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [object[]] $Applications,

        [Parameter(Mandatory = $false)]
        [string] $Search,

        [Parameter(Mandatory = $false)]
        [string] $Category = 'All',

        [Parameter(Mandatory = $false)]
        [switch] $FossOnly
    )

    $items = @($Applications)

    if (-not [string]::IsNullOrWhiteSpace($Search)) {
        $items = @(
            $items | Where-Object {
                $_.Name -like "*$Search*" -or
                $_.Key -like "*$Search*" -or
                $_.Description -like "*$Search*" -or
                $_.WingetId -like "*$Search*" -or
                $_.ChocoId -like "*$Search*"
            }
        )
    }

    if (-not [string]::IsNullOrWhiteSpace($Category) -and $Category -ne 'All') {
        $items = @($items | Where-Object { $_.Category -eq $Category })
    }

    if ($FossOnly) {
        $items = @($items | Where-Object { $_.Foss -eq $true })
    }

    return $items
}

function Get-KapselApplicationCategory {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [object[]] $Applications
    )

    return @('All') + @(
        $Applications |
            Select-Object -ExpandProperty Category -Unique |
            Sort-Object
    )
}

# Constructs the command-line arguments for installing or upgrading an application using the specified package manager.
function New-KapselPackageArgument {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet('Install', 'Upgrade')]
        [string] $Action,

        [Parameter(Mandatory = $true)]
        [object] $Application,

        [Parameter(Mandatory = $true)]
        [ValidateSet('winget', 'choco')]
        [string] $Provider
    )

    if ($Provider -eq 'winget') {
        if ([string]::IsNullOrWhiteSpace($Application.WingetId)) {
            throw "Application '$($Application.Name)' does not define a winget package id."
        }

        $verb = if ($Action -eq 'Install') { 'install' } else { 'upgrade' }
        return @(
            $verb,
            '--id', $Application.WingetId,
            '--exact',
            '--silent',
            '--accept-package-agreements',
            '--accept-source-agreements'
        )
    }

    if ([string]::IsNullOrWhiteSpace($Application.ChocoId)) {
        throw "Application '$($Application.Name)' does not define a Chocolatey package id."
    }

    $chocoVerb = if ($Action -eq 'Install') { 'install' } else { 'upgrade' }
    return @($chocoVerb, $Application.ChocoId, '-y')
}

# Executes the package manager command to install or upgrade the specified application and returns an object with the result.
function Invoke-KapselPackageAction {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet('Install', 'Upgrade')]
        [string] $Action,

        [Parameter(Mandatory = $true)]
        [object] $Application,

        [Parameter(Mandatory = $false)]
        [ValidateSet('winget', 'choco')]
        [string] $Provider = 'winget'
    )

    $managerStatus = Get-KapselPackageManagerStatus
    if ($Provider -eq 'winget' -and -not $managerStatus.WingetAvailable) {
        throw 'winget is not available on this system.'
    }

    if ($Provider -eq 'choco' -and -not $managerStatus.ChocoAvailable) {
        throw 'Chocolatey is not available on this system.'
    }

    $executable = if ($Provider -eq 'winget') { 'winget' } else { 'choco' }
    $arguments = New-KapselPackageArgument -Action $Action -Application $Application -Provider $Provider

    $process = Start-Process -FilePath $executable -ArgumentList $arguments -Wait -PassThru -NoNewWindow

    return [PSCustomObject] @{
        Application = $Application.Name
        Provider    = $Provider
        Action      = $Action
        ExitCode    = $process.ExitCode
        Succeeded   = $process.ExitCode -eq 0
        Command     = ('{0} {1}' -f $executable, ($arguments -join ' '))
    }
}

# Executes a batch of package actions for multiple applications and returns a summary of results.
function Invoke-KapselPackageBatch {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet('Install', 'Upgrade')]
        [string] $Action,

        [Parameter(Mandatory = $true)]
        [object[]] $Applications,

        [Parameter(Mandatory = $false)]
        [ValidateSet('winget', 'choco')]
        [string] $Provider = 'winget'
    )

    foreach ($application in $Applications) {
        try {
            Invoke-KapselPackageAction -Action $Action -Application $application -Provider $Provider
        }
        catch {
            [PSCustomObject] @{
                Application = $application.Name
                Provider    = $Provider
                Action      = $Action
                ExitCode    = $null
                Succeeded   = $false
                Command     = ''
                Error       = $_.Exception.Message
            }
        }
    }
}

Export-ModuleMember -Function @(
    'Get-KapselApplicationsPath',
    'Test-KapselCommandAvailable',
    'Get-KapselPackageManagerStatus',
    'Get-KapselApplicationCatalog',
    'Search-KapselApplicationCatalog',
    'Get-KapselApplicationCategory',
    'New-KapselPackageArgument',
    'Invoke-KapselPackageAction',
    'Invoke-KapselPackageBatch'
)


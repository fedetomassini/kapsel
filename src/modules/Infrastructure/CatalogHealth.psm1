# Read-only catalog freshness probes. Network access stays here; the catalog is never modified.
Set-StrictMode -Version Latest

if (-not ('System.Net.Http.HttpClient' -as [type])) {
    Add-Type -AssemblyName System.Net.Http
}

function Get-KapselLinkCheckOutcome {
    [CmdletBinding()]
    param(
        [int] $StatusCode = 0,
        [string] $ErrorMessage = ''
    )

    if ($StatusCode -ge 200 -and $StatusCode -le 399) { return 'Ok' }
    if ($StatusCode -eq 404 -or $StatusCode -eq 410) { return 'Broken' }
    return 'Inconclusive'
}

function Get-KapselProviderCheckOutcome {
    [CmdletBinding()]
    param(
        [int] $StatusCode = 0,
        [bool] $Found = $false,
        [string] $ErrorMessage = ''
    )

    if ($StatusCode -eq 404) { return 'Broken' }
    if ($StatusCode -ge 200 -and $StatusCode -le 299) {
        if ($Found) { return 'Ok' }
        return 'Broken'
    }
    return 'Inconclusive'
}

function Get-KapselWingetManifestPath {
    [CmdletBinding()]
    param(
        [AllowEmptyString()] [string] $PackageId
    )

    if ([string]::IsNullOrWhiteSpace($PackageId)) { return $null }
    $parts = @($PackageId -split '\.')
    if ($parts.Count -lt 2 -or @($parts | Where-Object { [string]::IsNullOrWhiteSpace($_) }).Count -gt 0) { return $null }
    $publisher = $parts[0]
    $first = $publisher.Substring(0, 1).ToLowerInvariant()
    $packagePath = @($parts[1..($parts.Count - 1)] | ForEach-Object { [Uri]::EscapeDataString($_) }) -join '/'
    return 'manifests/{0}/{1}/{2}' -f $first, [Uri]::EscapeDataString($publisher), $packagePath
}

function Invoke-KapselHttpStatusCheck {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)] [string[]] $Uris,
        [hashtable] $Headers = @{},
        [ValidateRange(1, 120)] [int] $TimeoutSeconds = 15,
        [ValidateRange(1, 32)] [int] $MaxConcurrency = 8
    )

    if ($Uris.Count -eq 0) { return @() }

    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    $handler = New-Object System.Net.Http.HttpClientHandler
    $handler.AllowAutoRedirect = $true
    $handler.MaxAutomaticRedirections = 5
    $handler.MaxConnectionsPerServer = $MaxConcurrency
    $client = New-Object System.Net.Http.HttpClient($handler)
    $client.Timeout = [TimeSpan]::FromSeconds($TimeoutSeconds)
    [void] $client.DefaultRequestHeaders.TryAddWithoutValidation('User-Agent', 'Kapsel-Catalog-Health/1.0')
    $results = New-Object System.Collections.Generic.List[object]
    try {
        # Chunk instead of queueing every request: HttpClient.Timeout includes time spent waiting
        # for a connection, so a large catalog would otherwise time out before a slot opens.
        for ($offset = 0; $offset -lt $Uris.Count; $offset += $MaxConcurrency) {
            $end = [Math]::Min($offset + $MaxConcurrency - 1, $Uris.Count - 1)
            $chunk = @($Uris[$offset..$end])
            $pending = New-Object System.Collections.Generic.List[object]
            foreach ($uri in $chunk) {
                $request = New-Object System.Net.Http.HttpRequestMessage([System.Net.Http.HttpMethod]::Get, $uri)
                foreach ($name in $Headers.Keys) {
                    [void] $request.Headers.TryAddWithoutValidation([string] $name, [string] $Headers[$name])
                }
                $pending.Add([PSCustomObject] @{
                    Request = $request
                    Task    = $client.SendAsync($request, [System.Net.Http.HttpCompletionOption]::ResponseHeadersRead)
                })
            }
            $tasks = [System.Threading.Tasks.Task[]] @($pending | ForEach-Object { $_.Task })
            try { [void] [System.Threading.Tasks.Task]::WaitAll($tasks, [TimeSpan]::FromSeconds($TimeoutSeconds + 5)) }
            catch { Write-Verbose 'One or more probes did not finish cleanly; each task is inspected below.' }

            foreach ($item in $pending) {
                $statusCode = 0
                $errorMessage = ''
                try {
                    if (-not $item.Task.IsCompleted) {
                        $errorMessage = 'Timed out'
                    }
                    elseif ($item.Task.IsFaulted) {
                        $errorMessage = $item.Task.Exception.GetBaseException().Message
                    }
                    elseif ($item.Task.IsCanceled) {
                        $errorMessage = 'Cancelled'
                    }
                    else {
                        $response = $item.Task.Result
                        try { $statusCode = [int] $response.StatusCode }
                        finally { $response.Dispose() }
                    }
                }
                catch {
                    $errorMessage = $_.Exception.Message
                }
                finally {
                    $item.Request.Dispose()
                }
                $results.Add([PSCustomObject] @{ StatusCode = $statusCode; Error = $errorMessage })
            }
        }
        return $results
    }
    finally {
        $client.Dispose()
    }
}

function Invoke-KapselCatalogLinkCheck {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)] [object[]] $Applications,
        [ValidateRange(1, 120)] [int] $TimeoutSeconds = 15,
        [ValidateRange(1, 32)] [int] $MaxConcurrency = 8
    )

    $items = @($Applications | Where-Object { -not [string]::IsNullOrWhiteSpace([string] $_.Link) })
    $statuses = @(Invoke-KapselHttpStatusCheck -Uris @($items | ForEach-Object { [string] $_.Link }) -TimeoutSeconds $TimeoutSeconds -MaxConcurrency $MaxConcurrency)
    $results = @{}
    for ($index = 0; $index -lt $items.Count; $index++) {
        $status = $statuses[$index]
        $results[[string] $items[$index].Key] = [PSCustomObject] @{
            Outcome    = Get-KapselLinkCheckOutcome -StatusCode $status.StatusCode -ErrorMessage $status.Error
            StatusCode = $status.StatusCode
            Error      = $status.Error
        }
    }
    return $results
}

function Invoke-KapselWingetIdCheck {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)] [object[]] $Applications,
        [ValidateRange(1, 120)] [int] $TimeoutSeconds = 15,
        [ValidateRange(1, 32)] [int] $MaxConcurrency = 8
    )

    $results = @{}
    $items = New-Object System.Collections.Generic.List[object]
    foreach ($application in $Applications) {
        $key = [string] $application.Key
        $packageId = [string] $application.WingetId
        if ([string]::IsNullOrWhiteSpace($packageId)) {
            $results[$key] = [PSCustomObject] @{ Outcome = 'Skipped'; StatusCode = 0; Error = '' }
            continue
        }
        $manifestPath = Get-KapselWingetManifestPath -PackageId $packageId
        if ([string]::IsNullOrWhiteSpace($manifestPath)) {
            $results[$key] = [PSCustomObject] @{ Outcome = 'Broken'; StatusCode = 0; Error = 'Invalid winget identifier.' }
            continue
        }
        $items.Add([PSCustomObject] @{ Key = $key; Uri = "https://api.github.com/repos/microsoft/winget-pkgs/contents/${manifestPath}?ref=master" })
    }

    $headers = @{ 'Accept' = 'application/vnd.github+json' }
    if (-not [string]::IsNullOrWhiteSpace($env:GITHUB_TOKEN)) {
        $headers['Authorization'] = "Bearer $($env:GITHUB_TOKEN)"
    }
    $statuses = @(Invoke-KapselHttpStatusCheck -Uris @($items | ForEach-Object { $_.Uri }) -Headers $headers -TimeoutSeconds $TimeoutSeconds -MaxConcurrency $MaxConcurrency)
    for ($index = 0; $index -lt $items.Count; $index++) {
        $status = $statuses[$index]
        $results[[string] $items[$index].Key] = [PSCustomObject] @{
            Outcome    = Get-KapselProviderCheckOutcome -StatusCode $status.StatusCode -Found ($status.StatusCode -ge 200 -and $status.StatusCode -le 299) -ErrorMessage $status.Error
            StatusCode = $status.StatusCode
            Error      = $status.Error
        }
    }
    return $results
}

function Invoke-KapselChocoIdCheck {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)] [object[]] $Applications,
        [ValidateRange(1, 120)] [int] $TimeoutSeconds = 15,
        [ValidateRange(1, 32)] [int] $MaxConcurrency = 4
    )

    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    $handler = New-Object System.Net.Http.HttpClientHandler
    $handler.AllowAutoRedirect = $true
    $handler.MaxAutomaticRedirections = 5
    $handler.MaxConnectionsPerServer = $MaxConcurrency
    $client = New-Object System.Net.Http.HttpClient($handler)
    $client.Timeout = [TimeSpan]::FromSeconds($TimeoutSeconds)
    [void] $client.DefaultRequestHeaders.TryAddWithoutValidation('User-Agent', 'Kapsel-Catalog-Health/1.0')
    $results = @{}
    $items = New-Object System.Collections.Generic.List[object]
    foreach ($application in $Applications) {
        $key = [string] $application.Key
        $packageId = [string] $application.ChocoId
        if ([string]::IsNullOrWhiteSpace($packageId)) {
            $results[$key] = [PSCustomObject] @{ Outcome = 'Skipped'; StatusCode = 0; Error = '' }
            continue
        }
        $filterValue = [Uri]::EscapeDataString("'$($packageId.Replace("'", "''"))'")
        $uri = "https://community.chocolatey.org/api/v2/FindPackagesById()?id=$filterValue&`$select=Id&`$top=1"
        $items.Add([PSCustomObject] @{ Key = $key; Uri = $uri })
    }
    try {
        # Chunk for the same reason as the status probe: a request queued behind a full
        # connection pool would consume its timeout before it ever starts.
        for ($offset = 0; $offset -lt $items.Count; $offset += $MaxConcurrency) {
            $end = [Math]::Min($offset + $MaxConcurrency - 1, $items.Count - 1)
            $chunk = @($items[$offset..$end])
            $pending = New-Object System.Collections.Generic.List[object]
            foreach ($item in $chunk) {
                $request = New-Object System.Net.Http.HttpRequestMessage([System.Net.Http.HttpMethod]::Get, $item.Uri)
                $pending.Add([PSCustomObject] @{
                    Key     = $item.Key
                    Request = $request
                    Task    = $client.SendAsync($request, [System.Net.Http.HttpCompletionOption]::ResponseContentRead)
                })
            }
            $tasks = [System.Threading.Tasks.Task[]] @($pending | ForEach-Object { $_.Task })
            try { [void] [System.Threading.Tasks.Task]::WaitAll($tasks, [TimeSpan]::FromSeconds($TimeoutSeconds + 5)) }
            catch { Write-Verbose 'One or more probes did not finish cleanly; each task is inspected below.' }

            foreach ($item in $pending) {
                $statusCode = 0
                $errorMessage = ''
                $found = $false
                try {
                    if (-not $item.Task.IsCompleted) {
                        $errorMessage = 'Timed out'
                    }
                    elseif ($item.Task.IsFaulted) {
                        $errorMessage = $item.Task.Exception.GetBaseException().Message
                    }
                    elseif ($item.Task.IsCanceled) {
                        $errorMessage = 'Cancelled'
                    }
                    else {
                        $response = $item.Task.Result
                        try {
                            $statusCode = [int] $response.StatusCode
                            if ($statusCode -ge 200 -and $statusCode -le 299) {
                                $body = $response.Content.ReadAsStringAsync().GetAwaiter().GetResult()
                                $found = $body -match '<entry[\s>]'
                            }
                        }
                        finally { $response.Dispose() }
                    }
                }
                catch {
                    $errorMessage = $_.Exception.Message
                }
                finally {
                    $item.Request.Dispose()
                }
                $results[$item.Key] = [PSCustomObject] @{
                    Outcome    = Get-KapselProviderCheckOutcome -StatusCode $statusCode -Found $found -ErrorMessage $errorMessage
                    StatusCode = $statusCode
                    Error      = $errorMessage
                }
            }
        }
        return $results
    }
    finally {
        $client.Dispose()
    }
}

function Get-KapselHealthResult {
    [CmdletBinding()]
    param(
        [hashtable] $Results,
        [string] $Key
    )

    if ($null -ne $Results -and $Results.ContainsKey($Key)) { return $Results[$Key] }
    return [PSCustomObject] @{ Outcome = 'Skipped'; StatusCode = 0; Error = '' }
}

function Get-KapselHealthCounts {
    [CmdletBinding()]
    param(
        [object[]] $Entries,
        [string] $Prefix
    )

    $counts = [PSCustomObject] @{ Ok = 0; Broken = 0; Inconclusive = 0; Skipped = 0 }
    foreach ($entry in $Entries) {
        $outcome = [string] $entry.PSObject.Properties["$($Prefix)Outcome"].Value
        if ($outcome -in @('Ok', 'Broken', 'Inconclusive', 'Skipped')) {
            $counts.$outcome = [int] $counts.$outcome + 1
        }
    }
    return $counts
}

function New-KapselCatalogHealthReport {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)] [object[]] $Applications,
        [hashtable] $LinkResults = @{},
        [hashtable] $WingetResults = @{},
        [hashtable] $ChocoResults = @{},
        [string] $CatalogPath = '',
        [string] $CatalogSha256 = '',
        [DateTime] $RecordedAt = [DateTime]::UtcNow
    )

    $entries = foreach ($application in $Applications) {
        $key = [string] $application.Key
        $link = Get-KapselHealthResult -Results $LinkResults -Key $key
        $winget = Get-KapselHealthResult -Results $WingetResults -Key $key
        $choco = Get-KapselHealthResult -Results $ChocoResults -Key $key
        [PSCustomObject] @{
            Key              = $key
            Name             = [string] $application.Name
            Link             = [string] $application.Link
            LinkOutcome      = [string] $link.Outcome
            LinkStatusCode   = [int] $link.StatusCode
            LinkError        = [string] $link.Error
            WingetId         = [string] $application.WingetId
            WingetOutcome    = [string] $winget.Outcome
            WingetStatusCode = [int] $winget.StatusCode
            WingetError      = [string] $winget.Error
            ChocoId          = [string] $application.ChocoId
            ChocoOutcome     = [string] $choco.Outcome
            ChocoStatusCode  = [int] $choco.StatusCode
            ChocoError       = [string] $choco.Error
            CheckedAt        = $RecordedAt.ToString('o')
        }
    }

    return [PSCustomObject] @{
        RecordedAt   = $RecordedAt.ToString('o')
        Runtime      = $PSVersionTable.PSVersion.ToString()
        CatalogPath  = $CatalogPath
        CatalogSha256 = $CatalogSha256
        Applications = $Applications.Count
        Links        = Get-KapselHealthCounts -Entries @($entries) -Prefix 'Link'
        WingetIds    = Get-KapselHealthCounts -Entries @($entries) -Prefix 'Winget'
        ChocoIds     = Get-KapselHealthCounts -Entries @($entries) -Prefix 'Choco'
        Entries      = @($entries)
    }
}

Export-ModuleMember -Function @(
    'Get-KapselLinkCheckOutcome',
    'Get-KapselProviderCheckOutcome',
    'Get-KapselWingetManifestPath',
    'Invoke-KapselCatalogLinkCheck',
    'Invoke-KapselWingetIdCheck',
    'Invoke-KapselChocoIdCheck',
    'New-KapselCatalogHealthReport'
)

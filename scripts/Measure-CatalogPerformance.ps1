# Measures catalog components without querying providers or installing software.
[CmdletBinding()]
param(
    [ValidateRange(1, 10000)] [int[]] $Sizes = @(1000, 5000),
    [ValidateRange(2, 20)] [int] $Iterations = 5,
    [string] $OutputPath
)

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
Import-Module (Join-Path $projectRoot 'src\modules\Application\CatalogService.psm1') -Force
Import-Module (Join-Path $projectRoot 'src\modules\Infrastructure\JsonCatalogRepository.psm1') -Force
Import-Module (Join-Path $projectRoot 'src\modules\Presentation\WinForms\ApplicationGridView.psm1') -Force
$catalog = @((New-KapselCatalogSnapshot -CatalogDocument (Read-KapselApplicationCatalogDocument)).Applications)
$results = @()
foreach ($size in @(@($catalog.Count) + $Sizes | Select-Object -Unique)) {
    $applications = if ($size -eq $catalog.Count) { $catalog } else {
        @(for ($index = 0; $index -lt $size; $index++) {
            $seed = $catalog[$index % $catalog.Count]
            [PSCustomObject] @{ Key = "app-$index"; Name = "$($seed.Name) $index"; Category = $seed.Category; Description = $seed.Description; WingetId = $seed.WingetId; ChocoId = $seed.ChocoId; Foss = $seed.Foss }
        })
    }
    $selected = @($applications | Select-Object -First ([int] ($size / 2)) | ForEach-Object { $_.Key })
    $form = New-Object System.Windows.Forms.Form
    $form.ClientSize = New-Object System.Drawing.Size(900, 500)
    $grid = New-KapselApplicationGrid
    $form.Controls.Add($grid)
    [void] $form.Handle
    [void] $grid.Handle
    try {
        $searchTimes = @()
        $bindTimes = @()
        $bulkTimes = @()
        for ($run = 0; $run -le $Iterations; $run++) {
            $watch = [Diagnostics.Stopwatch]::StartNew()
            $filtered = @(Find-KapselApplications -Applications $applications -Search 'firefox' -Category All)
            $watch.Stop()
            if ($run -gt 0) { $searchTimes += $watch.Elapsed.TotalMilliseconds }
            $watch.Restart()
            Set-KapselApplicationGrid -Grid $grid -Applications $applications -SelectedKeys $selected
            $watch.Stop()
            if ($run -gt 0) { $bindTimes += $watch.Elapsed.TotalMilliseconds }
            $watch.Restart()
            Set-KapselVisibleSelection -Grid $grid -Selected $true
            Set-KapselVisibleSelection -Grid $grid -Selected $false
            $watch.Stop()
            if ($run -gt 0) { $bulkTimes += $watch.Elapsed.TotalMilliseconds }
        }
        $results += [PSCustomObject] @{
            Applications = $size
            SearchMs = [Math]::Round(($searchTimes | Measure-Object -Average).Average, 1)
            GridBindMs = [Math]::Round(($bindTimes | Measure-Object -Average).Average, 1)
            SelectAndClearMs = [Math]::Round(($bulkTimes | Measure-Object -Average).Average, 1)
            SearchMatches = $filtered.Count
        }
    }
    finally { $form.Dispose() }
}
$report = [PSCustomObject] @{
    RecordedAt = [DateTime]::UtcNow.ToString('o')
    Runtime = $PSVersionTable.PSVersion.ToString()
    ProcessBits = [IntPtr]::Size * 8
    Processor = (Get-CimInstance Win32_Processor | Select-Object -First 1 -ExpandProperty Name)
    Iterations = $Iterations
    Measurement = 'Warmed component means; half the apps selected during binding. Excludes painting, composition-root event handlers, startup and provider queries.'
    Results = $results
}
$json = $report | ConvertTo-Json -Depth 4
if (-not [string]::IsNullOrWhiteSpace($OutputPath)) {
    $path = if ([IO.Path]::IsPathRooted($OutputPath)) { $OutputPath } else { Join-Path $projectRoot $OutputPath }
    [void] (New-Item -ItemType Directory -Path (Split-Path -Parent $path) -Force)
    [IO.File]::WriteAllText($path, $json, (New-Object Text.UTF8Encoding($false)))
}
$json

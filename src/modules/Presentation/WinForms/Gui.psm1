# WinForms composition root. It wires use cases, adapters, view state, and user events.
Set-StrictMode -Version Latest

$moduleRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
Import-Module (Join-Path $moduleRoot 'Application\CatalogService.psm1') -Force
Import-Module (Join-Path $moduleRoot 'Application\PackageService.psm1') -Force
Import-Module (Join-Path $moduleRoot 'Application\InventoryService.psm1') -Force
Import-Module (Join-Path $moduleRoot 'Application\PreferenceService.psm1') -Force
Import-Module (Join-Path $moduleRoot 'Infrastructure\AssetProvider.psm1') -Force
Import-Module (Join-Path $moduleRoot 'Infrastructure\JsonCatalogRepository.psm1') -Force
Import-Module (Join-Path $moduleRoot 'Infrastructure\PackageManagerAdapter.psm1') -Force
Import-Module (Join-Path $moduleRoot 'Infrastructure\PackageInventoryAdapter.psm1') -Force
Import-Module (Join-Path $moduleRoot 'Infrastructure\JsonPreferencesRepository.psm1') -Force
Import-Module (Join-Path $PSScriptRoot 'ApplicationGridView.psm1') -Force
Import-Module (Join-Path $PSScriptRoot 'CatalogView.psm1') -Force
Import-Module (Join-Path $PSScriptRoot 'ContextView.psm1') -Force
Import-Module (Join-Path $PSScriptRoot 'ShellView.psm1') -Force
Import-Module (Join-Path $PSScriptRoot 'SidebarView.psm1') -Force
Import-Module (Join-Path $PSScriptRoot 'Theme.psm1') -Force
Import-Module (Join-Path $PSScriptRoot 'WindowChrome.psm1') -Force
Import-Module (Join-Path $PSScriptRoot 'PackageOperationRunner.psm1') -Force
Import-Module (Join-Path $PSScriptRoot 'InventoryRunner.psm1') -Force

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

function New-KapselMainForm {
    [CmdletBinding()]
    param([Parameter(Mandatory = $true)] [object] $Metadata)

    return New-KapselBorderlessForm -Metadata $Metadata
}

function Show-KapselGui {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [object] $Metadata,
        [ValidateRange(1, 3600)] [int] $DelayWarningSeconds = 120
    )

    [System.Windows.Forms.Application]::SetUnhandledExceptionMode([System.Windows.Forms.UnhandledExceptionMode]::CatchException)
    [System.Windows.Forms.Application]::EnableVisualStyles()
    [System.Windows.Forms.Application]::SetCompatibleTextRenderingDefault($false)
    Initialize-KapselUiTheme

    $catalogDocument = Read-KapselApplicationCatalogDocument
    $snapshot = New-KapselCatalogSnapshot -CatalogDocument $catalogDocument
    $catalog = @($snapshot.Applications)
    $applicationsByKey = @{}
    foreach ($application in $catalog) { $applicationsByKey[[string] $application.Key] = $application }
    $favoriteKeys = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase)
    $preferencesWarning = ''
    $preferencesWritable = $true
    try {
        foreach ($key in @(Get-KapselFavorites -Applications $catalog -PreferencesReader { Read-KapselUserPreferences })) {
            [void] $favoriteKeys.Add([string] $key)
        }
    }
    catch {
        $preferencesWarning = $_.Exception.Message
        $preferencesWritable = $false
    }
    $providerStatus = Get-KapselPackageProviderStatus
    $defaultCategory = Get-KapselDefaultCategory -Categories $snapshot.Categories
    $selectedCategory = [PSCustomObject] @{ Value = $defaultCategory }
    $selectedKeys = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase)

    $form = New-KapselMainForm -Metadata $Metadata
    $threadExceptionHandler = [System.Threading.ThreadExceptionEventHandler] {
        param($sender, $eventArgs)

        if ($null -ne $form -and -not $form.IsDisposed) {
            [void] [System.Windows.Forms.MessageBox]::Show($form, $eventArgs.Exception.Message, 'Kapsel - UI error')
        }
    }
    [System.Windows.Forms.Application]::add_ThreadException($threadExceptionHandler)
    $brandImagePath = Get-KapselBrandImagePath
    $windowIcon = New-KapselWindowIcon -ImagePath $brandImagePath
    if ($null -ne $windowIcon) { $form.Icon = $windowIcon }

    $sidebarParameters = @{
        Metadata         = $Metadata
        Catalog          = $catalog
        Categories       = $snapshot.Categories
        DefaultCategory  = $defaultCategory
        ProviderStatus   = $providerStatus
        BrandImagePath   = $brandImagePath
    }
    $sidebar = New-KapselSidebarView @sidebarParameters
    $catalogView = New-KapselCatalogView -Snapshot $snapshot
    $contextView = New-KapselContextView -Metadata $Metadata
    $shell = New-KapselShellView -Form $form -Sidebar $sidebar.Panel -Catalog $catalogView.Panel -Context $contextView.Panel -Metadata $Metadata
    $form.Controls.Add($shell.Panel)
    $operation = [PSCustomObject] @{ Batch = $null; Busy = $false; Action = ''; Total = 0; Completed = 0; Succeeded = 0; Unchanged = 0; Failed = 0; Current = ''; Started = [DateTime]::UtcNow; CurrentStarted = [DateTime]::UtcNow; Delayed = $false; Cancellation = $null; Cancelled = 0; FailedItems = @(); Provider = '' }
    $operationTimer = New-Object System.Windows.Forms.Timer
    $operationTimer.Interval = 200
    $inventory = [PSCustomObject] @{ Scan = $null; Snapshot = $null; Filter = 'All'; Pending = $false; Status = 'Checking'; Diagnostics = @{}; CheckedAt = $null }
    $inventoryTimer = New-Object System.Windows.Forms.Timer
    $inventoryTimer.Interval = 250
    $viewState = [PSCustomObject] @{ VisibleApplications = @() }
    $searchTimer = New-Object System.Windows.Forms.Timer
    $searchTimer.Interval = 120

    $getSelectedApplications = {
        return @($catalog | Where-Object { $selectedKeys.Contains([string] $_.Key) })
    }

    $updateCurrentApplication = {
        $currentKey = Get-KapselCurrentApplicationKey -Grid $catalogView.Grid
        $application = if ($currentKey) { $applicationsByKey[$currentKey] } else { $null }
        $provider = [string] $sidebar.ProviderState.Value
        $state = if ($currentKey -and $null -ne $inventory.Snapshot -and $inventory.Snapshot.Provider -eq $provider) { $inventory.Snapshot.States[$currentKey] } else { $null }
        Set-KapselApplicationDetails -View $contextView -Application $application -Provider $provider -InventoryState $state -ProviderDiagnostics $inventory.Diagnostics[$provider]
        $catalogView.FavoriteButton.Enabled = $preferencesWritable -and $null -ne $application -and -not $operation.Busy
        $catalogView.OpenLinkButton.Enabled = $null -ne $application -and -not [string]::IsNullOrWhiteSpace($application.Link)
        $catalogView.FavoriteButton.Text = if (-not [string]::IsNullOrWhiteSpace($currentKey) -and $favoriteKeys.Contains($currentKey)) {
            'Unfavorite'
        }
        else { 'Favorite' }
        $catalogView.FavoriteButton.AccessibleName = $catalogView.FavoriteButton.Text
    }

    $updateActionState = {
        $count = $selectedKeys.Count
        $visibleCount = 0
        foreach ($application in $viewState.VisibleApplications) {
            if ($selectedKeys.Contains([string] $application.Key)) { $visibleCount++ }
        }
        $provider = [string] $sidebar.ProviderState.Value
        $supportedCount = 0
        if ($provider) {
            foreach ($key in $selectedKeys) {
                $application = $applicationsByKey[$key]
                if (($provider -eq 'winget' -and $application.WingetId) -or ($provider -eq 'choco' -and $application.ChocoId)) { $supportedCount++ }
            }
        }
        $catalogView.SelectionLabel.Text = if ($count -eq 0) { '0 selected' } else { "$count selected | $visibleCount visible | $($count - $visibleCount) hidden | $supportedCount supported" }
        $catalogView.SelectAllButton.Enabled = $viewState.VisibleApplications.Count -gt 0
        $catalogView.ClearButton.Enabled = $count -gt 0
        $catalogView.InstallButton.Enabled = $supportedCount -gt 0 -and -not $operation.Busy
        $catalogView.UpgradeButton.Enabled = $supportedCount -gt 0 -and -not $operation.Busy
        $shell.CancelButton.Enabled = $operation.Busy -and $null -ne $operation.Cancellation -and -not $operation.Cancellation.IsCancellationRequested
        $shell.RetryButton.Enabled = -not $operation.Busy -and $operation.FailedItems.Count -gt 0 -and $provider -eq $operation.Provider
        & $updateCurrentApplication
    }

    $synchronizeVisibleSelection = {
        [void] $catalogView.Grid.EndEdit()
        foreach ($row in $catalogView.Grid.Rows) {
            if ($row.IsNewRow) { continue }
            $key = [string] $row.Cells['Key'].Value
            if ($row.Cells['Selected'].Value -eq $true) {
                [void] $selectedKeys.Add($key)
            }
            else {
                [void] $selectedKeys.Remove($key)
            }
        }
        & $updateActionState
    }

    $refreshCatalog = {
        $searchTimer.Stop()
        $category = [string] $selectedCategory.Value
        $filterParameters = @{
            Applications = $catalog
            Search       = $catalogView.SearchBox.Text
            Category     = $category
            FossOnly     = $catalogView.FossOnly.Checked
        }
        $filtered = @(Find-KapselApplications @filterParameters)
        if ($inventory.Filter -eq 'Favorites') {
            $filtered = @($filtered | Where-Object { $favoriteKeys.Contains([string] $_.Key) })
        }
        $activeSnapshot = if ($null -ne $inventory.Snapshot -and $inventory.Snapshot.Provider -eq $sidebar.ProviderState.Value) { $inventory.Snapshot } else { $null }
        $providerName = [string] $sidebar.ProviderState.Value
        $catalogView.InventorySummary.Text = if ($null -ne $activeSnapshot) {
            $freshness = if ($inventory.Status -eq 'Ready') { 'Current' } elseif ($inventory.Status -eq 'Checking') { 'Previous; refreshing' } else { 'Previous; refresh failed' }
            "$($activeSnapshot.InstalledCount) installed  |  $($activeSnapshot.UpdateCount) updates | $providerName | $freshness | $($inventory.CheckedAt.ToLocalTime().ToString('yyyy-MM-dd HH:mm:ss'))"
        } else { "$providerName inventory: $($inventory.Status)" }
        if ($null -ne $activeSnapshot -and -not $activeSnapshot.UpdatesChecked) { $catalogView.InventorySummary.Text += ' | update check unavailable' }
        $catalogView.ToolTip.SetToolTip($catalogView.InventorySummary, $catalogView.InventorySummary.Text)
        $states = if ($null -ne $activeSnapshot) { $activeSnapshot.States } else { @{} }
        $inventoryFilter = if ($inventory.Filter -in @('Installed', 'Updates')) { $inventory.Filter } else { 'All' }
        $filtered = @(Find-KapselInventoryApplications -Applications $filtered -Snapshot $activeSnapshot -Filter $inventoryFilter)
        $viewState.VisibleApplications = $filtered
        Set-KapselApplicationGrid -Grid $catalogView.Grid -Applications $filtered -SelectedKeys ([string[]] @($selectedKeys)) -InventoryStates $states
        $catalogView.Grid.Visible = $filtered.Count -gt 0
        $catalogView.EmptyState.Visible = $filtered.Count -eq 0
        if ($filtered.Count -eq 0) {
            $catalogView.EmptyState.Text = if ($inventoryFilter -ne 'All' -and $inventory.Status -eq 'Checking') {
                "Checking $($sidebar.ProviderState.Value) inventory...`nInstalled and update results will appear when the scan finishes."
            }
            elseif ($inventoryFilter -ne 'All' -and $null -eq $activeSnapshot) {
                "Inventory is unavailable for this provider.`nSee Activity, press F5 to retry, or choose All to browse the catalog."
            }
            elseif ($inventoryFilter -eq 'Updates' -and -not $activeSnapshot.UpdatesChecked) {
                "The update check is unavailable.`nInstalled information is still available. Press F5 to retry."
            }
            elseif ($inventory.Filter -eq 'Favorites' -and $favoriteKeys.Count -eq 0) {
                "No favorites yet.`nChoose All, focus an application, and press Favorite to save it."
            }
            elseif (-not [string]::IsNullOrWhiteSpace($catalogView.SearchBox.Text) -or $catalogView.FossOnly.Checked) {
                "No applications match these filters.`nClear search with Escape or adjust the category and FOSS filter."
            }
            elseif ($inventoryFilter -eq 'Updates') {
                "No updates were reported for this view.`nChoose All to browse applications, or press F5 to check again."
            }
            elseif ($inventoryFilter -eq 'Installed') {
                "No installed applications were matched in this view.`nChoose All or another category. Not detected does not mean absent."
            }
            else { "No applications in this view.`nChoose All or another category." }
        }
        $catalogView.Title.Text = if ($inventory.Filter -eq 'Favorites') { 'Favorite applications' } elseif ($category -eq 'All') { 'All applications' } else { $category }
        $catalogView.Description.Text = if ($filtered.Count -eq 1) {
            '1 application matches the current view.'
        }
        else {
            "$($filtered.Count) applications match the current view."
        }
        if (-not $operation.Busy -and $shell.StatusLabel.Text -notmatch '^(Install|Upgrade) finished:') {
            $shell.StatusLabel.Text = "$($filtered.Count) visible / $($catalog.Count) total"
        }
        & $updateActionState
    }

    $setInventoryFilter = {
        param([ValidateSet('All', 'Favorites', 'Installed', 'Updates')] [string] $Filter)

        $inventory.Filter = $Filter
        $colors = Get-KapselUiColors
        foreach ($item in @(
            [PSCustomObject] @{ Name = 'All'; Button = $catalogView.AllButton },
            [PSCustomObject] @{ Name = 'Favorites'; Button = $catalogView.FavoritesButton },
            [PSCustomObject] @{ Name = 'Installed'; Button = $catalogView.InstalledButton },
            [PSCustomObject] @{ Name = 'Updates'; Button = $catalogView.UpdatesButton }
        )) {
            $active = $item.Name -eq $Filter
            $item.Button.BackColor = if ($active) { $colors.AccentDark } else { $colors.Surface }
            $item.Button.ForeColor = if ($active) { $colors.Accent } else { $colors.Text }
            $item.Button.FlatAppearance.BorderColor = if ($active) { $colors.Accent } else { $colors.Border }
        }
        & $refreshCatalog
    }

    $startInventoryScan = {
        $provider = [string] $sidebar.ProviderState.Value
        if ([string]::IsNullOrWhiteSpace($provider)) {
            $inventory.Snapshot = $null
            $inventory.Status = 'Missing'
            $catalogView.InventorySummary.Text = 'No package provider available'
            & $refreshCatalog
            return
        }
        if ($null -ne $inventory.Scan -and $inventory.Scan.Provider -ne $provider) {
            $inventory.Scan.Cancellation.Cancel()
            $inventory.Snapshot = $null
            $inventory.Status = 'Checking'
            $catalogView.InventorySummary.Text = "Waiting to check $provider..."
            & $refreshCatalog
        }
        if ($operation.Busy -or $null -ne $inventory.Scan) {
            $inventory.Pending = $true
            return
        }
        $inventory.Pending = $false
        # Keep the last same-provider snapshot visible, explicitly labelled as previous.
        $inventory.Status = 'Checking'
        $catalogView.InventorySummary.Text = "Checking $provider..."
        & $refreshCatalog
        try {
            $inventory.Scan = Start-KapselInventoryScan -Applications $catalog -Provider $provider
            $inventoryTimer.Start()
        }
        catch {
            $catalogView.InventorySummary.Text = 'Inventory unavailable'
            $inventory.Status = 'Unavailable'
            Write-KapselActivity -ActivityPanel $contextView.ActivityPanel -Message "Inventory check failed: $($_.Exception.Message)" -Level Warning
            & $refreshCatalog
        }
    }

    $inventoryTimer.Add_Tick({
        if ($null -eq $inventory.Scan -or -not $inventory.Scan.Handle.IsCompleted) { return }
        $inventoryTimer.Stop()
        $completedScan = $inventory.Scan
        $inventory.Scan = $null
        try {
            $result = @($completedScan.Worker.EndInvoke($completedScan.Handle)) | Select-Object -First 1
            if ($completedScan.Worker.Streams.Error.Count -gt 0) {
                throw ($completedScan.Worker.Streams.Error | Out-String)
            }
            if ($null -eq $result -or $null -eq $result.Snapshot) { throw 'The inventory worker returned no result.' }
            if ($completedScan.Provider -eq [string] $sidebar.ProviderState.Value) {
                $inventory.Snapshot = $result.Snapshot
                $inventory.Status = 'Ready'
                $inventory.CheckedAt = [DateTime]::UtcNow
                if ($null -ne $result.PSObject.Properties['Diagnostics'] -and $null -ne $result.Diagnostics) {
                    $inventory.Diagnostics[$completedScan.Provider] = $result.Diagnostics
                    Write-KapselActivity -ActivityPanel $contextView.ActivityPanel -Message "$($result.Diagnostics.Provider) $($result.Diagnostics.Version): $($result.Diagnostics.ExecutablePath)"
                }
                $catalogView.InventorySummary.Text = "$($result.Snapshot.InstalledCount) installed  |  $($result.Snapshot.UpdateCount) updates"
                if (-not $result.Snapshot.UpdatesChecked) {
                    $catalogView.InventorySummary.Text += '  |  update check unavailable'
                }
                & $refreshCatalog
                if (-not [string]::IsNullOrWhiteSpace([string] $result.Warning)) {
                    Write-KapselActivity -ActivityPanel $contextView.ActivityPanel -Message $result.Warning -Level Warning
                }
            }
        }
        catch {
            if (-not $completedScan.Cancellation.IsCancellationRequested) {
                $inventory.Status = 'Unavailable'
                $catalogView.InventorySummary.Text = 'Inventory unavailable'
                Write-KapselActivity -ActivityPanel $contextView.ActivityPanel -Message "Inventory check failed: $($_.Exception.Message)" -Level Warning
                & $refreshCatalog
            }
        }
        finally {
            $completedScan.Worker.Dispose()
            $completedScan.Cancellation.Dispose()
            if ($inventory.Pending -or $completedScan.Provider -ne [string] $sidebar.ProviderState.Value) {
                & $startInventoryScan
            }
        }
    })

    $runPackageAction = {
        param([ValidateSet('Install', 'Upgrade')] [string] $Action, [switch] $Retry)

        if ($operation.Busy) { return }
        if ($searchTimer.Enabled) { & $refreshCatalog }
        & $synchronizeVisibleSelection
        $selected = @(& $getSelectedApplications)
        if ($Retry) {
            if ([string] $sidebar.ProviderState.Value -ne $operation.Provider) { return }
            $selected = @($operation.FailedItems)
        }
        if ($selected.Count -eq 0) {
            [System.Windows.Forms.MessageBox]::Show('Select at least one application.', $Metadata.Name) | Out-Null
            return
        }

        $provider = [string] $sidebar.ProviderState.Value
        if ([string]::IsNullOrWhiteSpace($provider)) {
            [System.Windows.Forms.MessageBox]::Show('No supported package provider is available.', $Metadata.Name) | Out-Null
            return
        }

        $plan = New-KapselPackagePlan -Applications $selected -Provider $provider
        if ($plan.Supported.Count -eq 0) {
            [System.Windows.Forms.MessageBox]::Show("The selected applications do not support $provider.", $Metadata.Name) | Out-Null
            return
        }

        $message = "$Action $($plan.Supported.Count) application(s) with ${provider}?"
        if ($plan.Unsupported.Count -gt 0) {
            $message += " $($plan.Unsupported.Count) unsupported item(s) will be skipped."
        }
        $actionKeys = @($selected | ForEach-Object { $_.Key })
        $visibleSelected = @($viewState.VisibleApplications | Where-Object { $actionKeys -contains $_.Key }).Count
        $message += "`n$visibleSelected selected in this view; $($selected.Count - $visibleSelected) hidden by filters."
        $names = @($plan.Supported | Select-Object -First 8 | ForEach-Object { $_.Name })
        $message += "`n`n" + ($names -join "`n")
        if ($plan.Supported.Count -gt 8) { $message += "`n...and $($plan.Supported.Count - 8) more." }
        $answer = [System.Windows.Forms.MessageBox]::Show(
            $message,
            'Confirm package action',
            [System.Windows.Forms.MessageBoxButtons]::YesNo,
            [System.Windows.Forms.MessageBoxIcon]::Question
        )
        if ($answer -ne [System.Windows.Forms.DialogResult]::Yes) { return }

        if ($null -ne $inventory.Scan) {
            $inventory.Scan.Cancellation.Cancel()
            $inventory.Pending = $true
        }

        try {
            $operation.Busy = $true
            Set-KapselContextSection -State $contextView.State -Title 'Activity'
            $operation.Action = $Action
            $operation.Total = $plan.Supported.Count
            $operation.Completed = 0
            $operation.Succeeded = 0
            $operation.Unchanged = 0
            $operation.Failed = 0
            $operation.Cancelled = 0
            $operation.FailedItems = @()
            $operation.Provider = $provider
            $operation.Cancellation = New-Object System.Threading.CancellationTokenSource
            $operation.Current = 'Starting'
            $operation.Started = [DateTime]::UtcNow
            & $updateActionState
            $sidebar.WingetButton.Enabled = $false
            $sidebar.ChocoButton.Enabled = $false
            $shell.BatchProgress.Maximum = $operation.Total
            $shell.BatchProgress.Value = 0
            $shell.BatchProgress.Visible = $true
            $shell.CurrentProgress.Visible = $true
            $shell.StatusLabel.Text = "$Action in progress"

            foreach ($application in @($plan.Unsupported)) {
                Write-KapselActivity -ActivityPanel $contextView.ActivityPanel -Message "Skipped $($application.Name): $provider is not supported." -Level Warning
            }

            $operation.Batch = Start-KapselPackageBatch -Plan $plan -Action $Action -ProviderStatus $providerStatus -CancellationToken $operation.Cancellation.Token
            & $updateActionState
            $operationTimer.Start()
        }
        catch {
            if ($null -ne $operation.Cancellation) { $operation.Cancellation.Dispose(); $operation.Cancellation = $null }
            $operation.Busy = $false
            $shell.CurrentProgress.Visible = $false
            $shell.StatusLabel.Text = 'Could not start package operation'
            $sidebar.WingetButton.Enabled = $providerStatus.WingetAvailable
            $sidebar.ChocoButton.Enabled = $providerStatus.ChocoAvailable
            Write-KapselActivity -ActivityPanel $contextView.ActivityPanel -Message $_.Exception.Message -Level Error
            & $updateActionState
        }
    }

    $operationTimer.Add_Tick({
        if ($null -eq $operation.Batch) { return }
        try {
            # Snapshot completion before draining: a completing worker may still enqueue events.
            $finished = $operation.Batch.Handle.IsCompleted
            $event = $null
            while ($operation.Batch.Events.TryDequeue([ref] $event)) {
                if ($event.Kind -eq 'Started') {
                    $operation.Current = $event.Application
                    $operation.CurrentStarted = [DateTime]::UtcNow
                    $operation.Delayed = $false
                    Write-KapselActivity -ActivityPanel $contextView.ActivityPanel -Message "$($operation.Action): $($event.Application)."
                    continue
                }
                $operation.Completed++
                $shell.BatchProgress.Value = $operation.Completed
                if ($event.Kind -eq 'Cancelled') {
                    $operation.Cancelled++
                    Write-KapselActivity -ActivityPanel $contextView.ActivityPanel -Message "Cancelled before start: $($event.Application)." -Level Warning
                    continue
                }
                if ($event.Kind -eq 'Completed' -and $event.Result.Succeeded) {
                    $unchanged = $event.Result.Status -in @('UpToDate', 'AlreadyInstalled')
                    if ($unchanged) { $operation.Unchanged++ } else { $operation.Succeeded++ }
                    $level = if ($unchanged) { 'Info' } elseif ($event.Result.Status -eq 'RestartRequired') { 'Warning' } else { 'Success' }
                    Write-KapselActivity -ActivityPanel $contextView.ActivityPanel -Message "$($event.Application): $($event.Result.Message)" -Level $level
                    if ($event.Result.Provider -eq 'choco' -and -not [string]::IsNullOrWhiteSpace($event.Result.Diagnostics)) {
                        Write-KapselActivity -ActivityPanel $contextView.ActivityPanel -Message $event.Result.Diagnostics
                    }
                }
                else {
                    $operation.Failed++
                    $operation.FailedItems += $event.Item
                    $detail = if ($event.Kind -eq 'Failed') { $event.Message } else {
                        $providerDetail = if ([string]::IsNullOrWhiteSpace($event.Result.Diagnostics)) { 'The provider returned no further details.' } else { $event.Result.Diagnostics }
                        "$($event.Result.Message)`n$providerDetail"
                    }
                    Write-KapselActivity -ActivityPanel $contextView.ActivityPanel -Message "Failed: $($event.Application). $detail" -Level Error
                }
            }
            $elapsed = [int] ([DateTime]::UtcNow - $operation.Started).TotalSeconds
            $currentElapsed = [int] ([DateTime]::UtcNow - $operation.CurrentStarted).TotalSeconds
            $shell.StatusLabel.Text = "$($operation.Action): $($operation.Current) | $($operation.Completed)/$($operation.Total) completed | app ${currentElapsed}s / batch ${elapsed}s"
            if (-not $finished -and $currentElapsed -ge $DelayWarningSeconds -and -not $operation.Delayed) {
                $operation.Delayed = $true
                Write-KapselActivity -ActivityPanel $contextView.ActivityPanel -Message "$($operation.Current) has been running for at least $DelayWarningSeconds seconds. It may still be working. Stop pending prevents subsequent packages; the active installer will not be killed. Closing remains blocked until it returns." -Level Warning
            }
            if ($operation.Delayed) { $shell.StatusLabel.Text += ' | Taking longer than expected' }
            if ($operation.Cancellation.IsCancellationRequested) { $shell.StatusLabel.Text += ' | Stopping after current app' }
            if (-not $finished) { return }
            [void] $operation.Batch.Worker.EndInvoke($operation.Batch.Handle)
            if ($operation.Batch.Worker.Streams.Error.Count -gt 0) { throw ($operation.Batch.Worker.Streams.Error | Out-String) }
            $shell.StatusLabel.Text = "$($operation.Action) finished: $($operation.Succeeded) succeeded, $($operation.Failed) failed"
            if ($operation.Unchanged -gt 0) {
                $shell.StatusLabel.Text = "$($operation.Action) finished: $($operation.Succeeded) completed, $($operation.Unchanged) unchanged, $($operation.Failed) failed"
            }
            $summaryLevel = if ($operation.Failed -gt 0) { 'Warning' } else { 'Success' }
            if ($operation.Cancelled -gt 0) { $shell.StatusLabel.Text += ", $($operation.Cancelled) cancelled"; $summaryLevel = 'Warning' }
            Write-KapselActivity -ActivityPanel $contextView.ActivityPanel -Message $shell.StatusLabel.Text -Level $summaryLevel
        }
        catch {
            $finished = $true
            $shell.StatusLabel.Text = 'Package operation interrupted; see Activity'
            Write-KapselActivity -ActivityPanel $contextView.ActivityPanel -Message $_.Exception.Message -Level Error
        }
        finally {
            if ($finished) {
                $operationTimer.Stop()
                $operation.Batch.Worker.Dispose()
                $operation.Batch = $null
                $operation.Cancellation.Dispose()
                $operation.Cancellation = $null
                $operation.Busy = $false
                $shell.CurrentProgress.Visible = $false
                $sidebar.WingetButton.Enabled = $providerStatus.WingetAvailable
                $sidebar.ChocoButton.Enabled = $providerStatus.ChocoAvailable
                & $updateActionState
                & $startInventoryScan
            }
        }
    })
    $form.Add_FormClosing({
        param($sender, $eventArgs)
        if ($operation.Busy) {
            $eventArgs.Cancel = $true
            [void] [System.Windows.Forms.MessageBox]::Show($form, 'Wait for the package operation to finish before closing Kapsel. You can minimize the window.', $Metadata.Name)
        }
    })

    $catalogView.RefreshButton.Add_Click({ & $startInventoryScan })
    $shell.CancelButton.Add_Click({
        if ($operation.Busy -and $null -ne $operation.Cancellation) {
            $operation.Cancellation.Cancel()
            Write-KapselActivity -ActivityPanel $contextView.ActivityPanel -Message 'Stop pending requested. The active installer is allowed to finish; remaining packages will not start.' -Level Warning
            & $updateActionState
        }
    })
    $shell.RetryButton.Add_Click({ & $runPackageAction $operation.Action -Retry })
    $catalogView.AllButton.Add_Click({ & $setInventoryFilter 'All' })
    $catalogView.FavoritesButton.Add_Click({ & $setInventoryFilter 'Favorites' })
    $catalogView.InstalledButton.Add_Click({ & $setInventoryFilter 'Installed' })
    $catalogView.UpdatesButton.Add_Click({ & $setInventoryFilter 'Updates' })
    $searchTimer.Add_Tick($refreshCatalog)
    $catalogView.SearchBox.Add_TextChanged({
        $searchTimer.Stop()
        if ([string]::IsNullOrEmpty($catalogView.SearchBox.Text)) { & $refreshCatalog } else { $searchTimer.Start() }
    })
    $catalogView.SearchBox.Add_KeyDown({
        param($sender, $eventArgs)
        if ($eventArgs.KeyCode -eq [System.Windows.Forms.Keys]::Down) {
            if ($searchTimer.Enabled) { & $refreshCatalog }
            if ($catalogView.Grid.Rows.Count -gt 0) { [void] $catalogView.Grid.Focus() }
            $eventArgs.SuppressKeyPress = $true
        }
    })
    $catalogView.FossOnly.Add_CheckedChanged($refreshCatalog)
    $catalogView.Grid.Add_CurrentCellDirtyStateChanged({
        if ($catalogView.Grid.IsCurrentCellDirty) {
            $catalogView.Grid.CommitEdit([System.Windows.Forms.DataGridViewDataErrorContexts]::Commit)
        }
    })
    $catalogView.Grid.Add_CellValueChanged({
        param($sender, $eventArgs)
        if ($sender.Tag.Updating -or $eventArgs.RowIndex -lt 0 -or $eventArgs.ColumnIndex -lt 0 -or $sender.Columns[$eventArgs.ColumnIndex].Name -ne 'Selected') { return }
        $row = $sender.Rows[$eventArgs.RowIndex]
        $key = [string] $row.Cells['Key'].Value
        if ($row.Cells['Selected'].Value -eq $true) { [void] $selectedKeys.Add($key) } else { [void] $selectedKeys.Remove($key) }
        & $updateActionState
    })
    $catalogView.Grid.Add_CurrentCellChanged({ if (-not $catalogView.Grid.Tag.Updating) { & $updateCurrentApplication } })

    $sidebar.CategoryTree.Add_AfterSelect({
        if ($null -ne $sidebar.CategoryTree.SelectedNode -and $null -ne $sidebar.CategoryTree.SelectedNode.Tag) {
            $selectedCategory.Value = [string] $sidebar.CategoryTree.SelectedNode.Tag
            & $refreshCatalog
        }
    })
    $sidebar.WingetButton.Add_Click({
        Write-KapselActivity -ActivityPanel $contextView.ActivityPanel -Message 'Package provider changed to winget.'
        & $updateActionState
        & $startInventoryScan
    })
    $sidebar.ChocoButton.Add_Click({
        Write-KapselActivity -ActivityPanel $contextView.ActivityPanel -Message 'Package provider changed to choco.'
        & $updateActionState
        & $startInventoryScan
    })

    $catalogView.SelectAllButton.Add_Click({
        if ($searchTimer.Enabled) { & $refreshCatalog }
        Set-KapselVisibleSelection -Grid $catalogView.Grid -Selected $true
        & $synchronizeVisibleSelection
    })
    $catalogView.ClearButton.Add_Click({
        $selectedKeys.Clear()
        Set-KapselVisibleSelection -Grid $catalogView.Grid -Selected $false
        & $updateActionState
    })
    $catalogView.FavoriteButton.Add_Click({
        $key = Get-KapselCurrentApplicationKey -Grid $catalogView.Grid
        if ([string]::IsNullOrWhiteSpace($key)) { return }
        $isFavorite = -not $favoriteKeys.Contains($key)
        try {
            $updated = @(Set-KapselFavorite -FavoriteKeys @($favoriteKeys) -Applications $catalog -Key $key -IsFavorite $isFavorite -PreferencesWriter {
                param($preferences)
                Write-KapselUserPreferences -Preferences $preferences
            })
            $favoriteKeys.Clear()
            foreach ($favoriteKey in $updated) { [void] $favoriteKeys.Add([string] $favoriteKey) }
            $application = $applicationsByKey[$key]
            $verb = if ($isFavorite) { 'Added to favorites' } else { 'Removed from favorites' }
            Write-KapselActivity -ActivityPanel $contextView.ActivityPanel -Message "$verb`: $($application.Name)." -Level Success
            & $refreshCatalog
        }
        catch {
            Write-KapselActivity -ActivityPanel $contextView.ActivityPanel -Message "Favorites could not be saved: $($_.Exception.Message)" -Level Error
        }
    })
    $catalogView.InstallButton.Add_Click({ & $runPackageAction 'Install' })
    $catalogView.UpgradeButton.Add_Click({ & $runPackageAction 'Upgrade' })
    $catalogView.OpenLinkButton.Add_Click({
        $key = Get-KapselCurrentApplicationKey -Grid $catalogView.Grid
        if ([string]::IsNullOrWhiteSpace($key)) {
            $selected = @(& $getSelectedApplications)
            if ($selected.Count -gt 0) { $key = [string] $selected[0].Key }
        }

        $application = $applicationsByKey[$key]
        if ($null -eq $application -or [string]::IsNullOrWhiteSpace([string] $application.Link)) {
            [System.Windows.Forms.MessageBox]::Show('Select an application with an official website.', $Metadata.Name) | Out-Null
            return
        }

        try { Start-Process -FilePath $application.Link -ErrorAction Stop }
        catch { [System.Windows.Forms.MessageBox]::Show($_.Exception.Message, $Metadata.Name) | Out-Null }
    })

    $form.Add_KeyDown({
        param($sender, $eventArgs)
        if ($eventArgs.Control -and $eventArgs.KeyCode -eq [System.Windows.Forms.Keys]::F) {
            [void] $catalogView.SearchBox.Focus()
            $eventArgs.SuppressKeyPress = $true
        }
        elseif ($eventArgs.KeyCode -eq [System.Windows.Forms.Keys]::Escape -and -not [string]::IsNullOrEmpty($catalogView.SearchBox.Text)) {
            $catalogView.SearchBox.Clear()
            $eventArgs.SuppressKeyPress = $true
        }
        elseif ($eventArgs.KeyCode -eq [System.Windows.Forms.Keys]::F5) {
            & $startInventoryScan
            $eventArgs.SuppressKeyPress = $true
        }
        elseif ($eventArgs.Control -and $eventArgs.KeyCode -eq [System.Windows.Forms.Keys]::A -and -not $catalogView.SearchBox.Focused) {
            if ($eventArgs.Shift) { $catalogView.ClearButton.PerformClick() } else { $catalogView.SelectAllButton.PerformClick() }
            $eventArgs.SuppressKeyPress = $true
        }
        elseif ($eventArgs.KeyCode -eq [System.Windows.Forms.Keys]::F6) {
            $targets = @($catalogView.SearchBox, $catalogView.Grid, $sidebar.CategoryTree, $contextView.State.Buttons['Details'])
            $index = -1
            for ($i = 0; $i -lt $targets.Count; $i++) { if ($targets[$i].ContainsFocus) { $index = $i; break } }
            $next = ($index + $(if ($eventArgs.Shift) { $targets.Count - 1 } else { 1 })) % $targets.Count
            if (-not $targets[$next].Visible) { $next = 2 }
            [void] $targets[$next].Focus()
            $eventArgs.SuppressKeyPress = $true
        }
    })
    $form.Add_FormClosed({
        if ($null -ne $windowIcon) { $windowIcon.Dispose() }
    })

    & $refreshCatalog
    Write-KapselActivity -ActivityPanel $contextView.ActivityPanel -Message "Catalog loaded with $($catalog.Count) applications." -Level Success
    if (-not [string]::IsNullOrWhiteSpace($preferencesWarning)) {
        Write-KapselActivity -ActivityPanel $contextView.ActivityPanel -Message $preferencesWarning -Level Warning
        $catalogView.ToolTip.SetToolTip($catalogView.FavoriteButton, $preferencesWarning)
        Set-KapselContextSection -State $contextView.State -Title 'Activity'
    }
    $form.Add_Shown({ [void] $catalogView.SearchBox.Focus(); & $startInventoryScan })
    try {
        [void] $form.ShowDialog()
    }
    finally {
        [System.Windows.Forms.Application]::remove_ThreadException($threadExceptionHandler)
        $inventoryTimer.Stop()
        $inventoryTimer.Dispose()
        if ($null -ne $inventory.Scan) {
            $inventory.Scan.Cancellation.Cancel()
            [void] $inventory.Scan.Handle.AsyncWaitHandle.WaitOne(5000)
            $inventory.Scan.Worker.Dispose()
            $inventory.Scan.Cancellation.Dispose()
        }
        $operationTimer.Dispose()
        $searchTimer.Stop()
        $searchTimer.Dispose()
        $form.Dispose()
    }
}

Export-ModuleMember -Function 'Show-KapselGui'

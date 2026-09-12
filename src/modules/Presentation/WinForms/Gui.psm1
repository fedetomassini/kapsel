# WinForms composition root. It wires use cases, adapters, view state, and user events.
Set-StrictMode -Version Latest

$moduleRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
Import-Module (Join-Path $moduleRoot 'Application\CatalogService.psm1') -Force
Import-Module (Join-Path $moduleRoot 'Application\PackageService.psm1') -Force
Import-Module (Join-Path $moduleRoot 'Application\InventoryService.psm1') -Force
Import-Module (Join-Path $moduleRoot 'Infrastructure\AssetProvider.psm1') -Force
Import-Module (Join-Path $moduleRoot 'Infrastructure\JsonCatalogRepository.psm1') -Force
Import-Module (Join-Path $moduleRoot 'Infrastructure\PackageManagerAdapter.psm1') -Force
Import-Module (Join-Path $moduleRoot 'Infrastructure\PackageInventoryAdapter.psm1') -Force
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
        [object] $Metadata
    )

    [System.Windows.Forms.Application]::SetUnhandledExceptionMode([System.Windows.Forms.UnhandledExceptionMode]::CatchException)
    [System.Windows.Forms.Application]::EnableVisualStyles()
    [System.Windows.Forms.Application]::SetCompatibleTextRenderingDefault($false)
    Initialize-KapselUiTheme

    $catalogDocument = Read-KapselApplicationCatalogDocument
    $snapshot = New-KapselCatalogSnapshot -CatalogDocument $catalogDocument
    $catalog = @($snapshot.Applications)
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
    $operation = [PSCustomObject] @{ Batch = $null; Busy = $false; Action = ''; Total = 0; Completed = 0; Succeeded = 0; Unchanged = 0; Failed = 0; Current = ''; Started = [DateTime]::UtcNow }
    $operationTimer = New-Object System.Windows.Forms.Timer
    $operationTimer.Interval = 200
    $inventory = [PSCustomObject] @{ Scan = $null; Snapshot = $null; Filter = 'All'; Pending = $false }
    $inventoryTimer = New-Object System.Windows.Forms.Timer
    $inventoryTimer.Interval = 250

    $getSelectedApplications = {
        return @($catalog | Where-Object { $selectedKeys.Contains([string] $_.Key) })
    }

    $updateActionState = {
        $count = $selectedKeys.Count
        $catalogView.SelectionLabel.Text = "$count selected"
        $hasProvider = -not [string]::IsNullOrWhiteSpace([string] $sidebar.ProviderState.Value)
        $catalogView.InstallButton.Enabled = $count -gt 0 -and $hasProvider -and -not $operation.Busy
        $catalogView.UpgradeButton.Enabled = $count -gt 0 -and $hasProvider -and -not $operation.Busy
    }

    $synchronizeVisibleSelection = {
        $catalogView.Grid.EndEdit()
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
        $category = [string] $selectedCategory.Value
        $filterParameters = @{
            Applications = $catalog
            Search       = $catalogView.SearchBox.Text
            Category     = $category
            FossOnly     = $catalogView.FossOnly.Checked
        }
        $filtered = @(Find-KapselApplications @filterParameters)
        $activeSnapshot = if ($null -ne $inventory.Snapshot -and $inventory.Snapshot.Provider -eq $sidebar.ProviderState.Value) { $inventory.Snapshot } else { $null }
        $states = if ($null -ne $activeSnapshot) { $activeSnapshot.States } else { @{} }
        $filtered = @(Find-KapselInventoryApplications -Applications $filtered -Snapshot $activeSnapshot -Filter $inventory.Filter)
        Set-KapselApplicationGrid -Grid $catalogView.Grid -Applications $filtered -SelectedKeys ([string[]] @($selectedKeys)) -InventoryStates $states
        $catalogView.Title.Text = if ($category -eq 'All') { 'All applications' } else { $category }
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
        param([ValidateSet('All', 'Installed', 'Updates')] [string] $Filter)

        $inventory.Filter = $Filter
        $colors = Get-KapselUiColors
        foreach ($item in @(
            [PSCustomObject] @{ Name = 'All'; Button = $catalogView.AllButton },
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
            $catalogView.InventorySummary.Text = 'No package provider available'
            & $refreshCatalog
            return
        }
        if ($null -ne $inventory.Scan -and $inventory.Scan.Provider -ne $provider) {
            $inventory.Scan.Cancellation.Cancel()
            $inventory.Snapshot = $null
            $catalogView.InventorySummary.Text = "Waiting to check $provider..."
            & $refreshCatalog
        }
        if ($operation.Busy -or $null -ne $inventory.Scan) {
            $inventory.Pending = $true
            return
        }
        $inventory.Pending = $false
        $inventory.Snapshot = $null
        $catalogView.InventorySummary.Text = "Checking $provider..."
        & $refreshCatalog
        try {
            $inventory.Scan = Start-KapselInventoryScan -Applications $catalog -Provider $provider
            $inventoryTimer.Start()
        }
        catch {
            $catalogView.InventorySummary.Text = 'Inventory unavailable'
            Write-KapselActivity -ActivityPanel $contextView.ActivityPanel -Message "Inventory check failed: $($_.Exception.Message)" -Level Warning
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
                $inventory.Snapshot = $null
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
        param([ValidateSet('Install', 'Upgrade')] [string] $Action)

        if ($operation.Busy) { return }
        & $synchronizeVisibleSelection
        $selected = @(& $getSelectedApplications)
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
            $operation.Action = $Action
            $operation.Total = $plan.Supported.Count
            $operation.Completed = 0
            $operation.Succeeded = 0
            $operation.Unchanged = 0
            $operation.Failed = 0
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

            $operation.Batch = Start-KapselPackageBatch -Plan $plan -Action $Action -ProviderStatus $providerStatus
            $operationTimer.Start()
        }
        catch {
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
                    Write-KapselActivity -ActivityPanel $contextView.ActivityPanel -Message "$($operation.Action): $($event.Application)."
                    continue
                }
                $operation.Completed++
                $shell.BatchProgress.Value = $operation.Completed
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
                    $detail = if ($event.Kind -eq 'Failed') { $event.Message } else {
                        $providerDetail = if ([string]::IsNullOrWhiteSpace($event.Result.Diagnostics)) { 'The provider returned no further details.' } else { $event.Result.Diagnostics }
                        "$($event.Result.Message)`n$providerDetail"
                    }
                    Write-KapselActivity -ActivityPanel $contextView.ActivityPanel -Message "Failed: $($event.Application). $detail" -Level Error
                }
            }
            $elapsed = [int] ([DateTime]::UtcNow - $operation.Started).TotalSeconds
            $shell.StatusLabel.Text = "$($operation.Action): $($operation.Current) | $($operation.Completed)/$($operation.Total) completed | ${elapsed}s"
            if (-not $finished) { return }
            [void] $operation.Batch.Worker.EndInvoke($operation.Batch.Handle)
            if ($operation.Batch.Worker.Streams.Error.Count -gt 0) { throw ($operation.Batch.Worker.Streams.Error | Out-String) }
            $shell.StatusLabel.Text = "$($operation.Action) finished: $($operation.Succeeded) succeeded, $($operation.Failed) failed"
            if ($operation.Unchanged -gt 0) {
                $shell.StatusLabel.Text = "$($operation.Action) finished: $($operation.Succeeded) completed, $($operation.Unchanged) unchanged, $($operation.Failed) failed"
            }
            $summaryLevel = if ($operation.Failed -gt 0) { 'Warning' } else { 'Success' }
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
    $catalogView.AllButton.Add_Click({ & $setInventoryFilter 'All' })
    $catalogView.InstalledButton.Add_Click({ & $setInventoryFilter 'Installed' })
    $catalogView.UpdatesButton.Add_Click({ & $setInventoryFilter 'Updates' })
    $catalogView.SearchBox.Add_TextChanged($refreshCatalog)
    $catalogView.FossOnly.Add_CheckedChanged($refreshCatalog)
    $catalogView.Grid.Add_CurrentCellDirtyStateChanged({
        if ($catalogView.Grid.IsCurrentCellDirty) {
            $catalogView.Grid.CommitEdit([System.Windows.Forms.DataGridViewDataErrorContexts]::Commit)
        }
    })
    $catalogView.Grid.Add_CellValueChanged({ & $synchronizeVisibleSelection })

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
        foreach ($row in $catalogView.Grid.Rows) {
            if (-not $row.IsNewRow) {
                $row.Cells['Selected'].Value = $true
                [void] $selectedKeys.Add([string] $row.Cells['Key'].Value)
            }
        }
        & $updateActionState
    })
    $catalogView.ClearButton.Add_Click({
        $selectedKeys.Clear()
        foreach ($row in $catalogView.Grid.Rows) {
            if (-not $row.IsNewRow) { $row.Cells['Selected'].Value = $false }
        }
        & $updateActionState
    })
    $catalogView.InstallButton.Add_Click({ & $runPackageAction 'Install' })
    $catalogView.UpgradeButton.Add_Click({ & $runPackageAction 'Upgrade' })
    $catalogView.OpenLinkButton.Add_Click({
        $key = Get-KapselCurrentApplicationKey -Grid $catalogView.Grid
        if ([string]::IsNullOrWhiteSpace($key)) {
            $selected = @(& $getSelectedApplications)
            if ($selected.Count -gt 0) { $key = [string] $selected[0].Key }
        }

        $application = $catalog | Where-Object { $_.Key -eq $key } | Select-Object -First 1
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
            $catalogView.SearchBox.Focus()
            $eventArgs.SuppressKeyPress = $true
        }
        elseif ($eventArgs.KeyCode -eq [System.Windows.Forms.Keys]::Escape -and -not [string]::IsNullOrEmpty($catalogView.SearchBox.Text)) {
            $catalogView.SearchBox.Clear()
            $eventArgs.SuppressKeyPress = $true
        }
    })
    $form.Add_FormClosed({
        if ($null -ne $windowIcon) { $windowIcon.Dispose() }
    })

    & $refreshCatalog
    Write-KapselActivity -ActivityPanel $contextView.ActivityPanel -Message "Catalog loaded with $($catalog.Count) applications." -Level Success
    $form.Add_Shown({ & $startInventoryScan })
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
        $form.Dispose()
    }
}

Export-ModuleMember -Function 'Show-KapselGui'

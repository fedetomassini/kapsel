# WinForms composition root. It wires use cases, adapters, view state, and user events.
Set-StrictMode -Version Latest

$moduleRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
Import-Module (Join-Path $moduleRoot 'Application\CatalogService.psm1') -Force
Import-Module (Join-Path $moduleRoot 'Application\PackageService.psm1') -Force
Import-Module (Join-Path $moduleRoot 'Infrastructure\AssetProvider.psm1') -Force
Import-Module (Join-Path $moduleRoot 'Infrastructure\JsonCatalogRepository.psm1') -Force
Import-Module (Join-Path $moduleRoot 'Infrastructure\PackageManagerAdapter.psm1') -Force
Import-Module (Join-Path $PSScriptRoot 'ApplicationGridView.psm1') -Force
Import-Module (Join-Path $PSScriptRoot 'CatalogView.psm1') -Force
Import-Module (Join-Path $PSScriptRoot 'ContextView.psm1') -Force
Import-Module (Join-Path $PSScriptRoot 'ShellView.psm1') -Force
Import-Module (Join-Path $PSScriptRoot 'SidebarView.psm1') -Force
Import-Module (Join-Path $PSScriptRoot 'Theme.psm1') -Force
Import-Module (Join-Path $PSScriptRoot 'WindowChrome.psm1') -Force

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
    $uiExceptionState = [PSCustomObject] @{ Exception = $null }
    $threadExceptionHandler = [System.Threading.ThreadExceptionEventHandler] {
        param($sender, $eventArgs)

        $uiExceptionState.Exception = $eventArgs.Exception
        if ($null -ne $form -and -not $form.IsDisposed) {
            $form.Close()
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

    $getSelectedApplications = {
        return @($catalog | Where-Object { $selectedKeys.Contains([string] $_.Key) })
    }

    $updateActionState = {
        $count = $selectedKeys.Count
        $catalogView.SelectionLabel.Text = if ($count -eq 1) { '1 application selected' } else { "$count applications selected" }
        $hasProvider = -not [string]::IsNullOrWhiteSpace([string] $sidebar.ProviderState.Value)
        $catalogView.InstallButton.Enabled = $count -gt 0 -and $hasProvider
        $catalogView.UpgradeButton.Enabled = $count -gt 0 -and $hasProvider
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
        Set-KapselApplicationGrid -Grid $catalogView.Grid -Applications $filtered -SelectedKeys ([string[]] @($selectedKeys))
        $catalogView.Title.Text = if ($category -eq 'All') { 'All applications' } else { $category }
        $catalogView.Description.Text = if ($filtered.Count -eq 1) {
            '1 application matches the current view.'
        }
        else {
            "$($filtered.Count) applications match the current view."
        }
        $shell.StatusLabel.Text = "$($filtered.Count) visible / $($catalog.Count) total"
        & $updateActionState
    }

    $invokePackageProcess = {
        param([object] $Command)
        return Invoke-KapselPackageProcess -Command $Command
    }

    $runPackageAction = {
        param([ValidateSet('Install', 'Upgrade')] [string] $Action)

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

        $message = "$Action $($plan.Supported.Count) application(s) with $provider?"
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

        $succeeded = 0
        $failed = 0
        try {
            $form.Cursor = [System.Windows.Forms.Cursors]::WaitCursor
            $catalogView.InstallButton.Enabled = $false
            $catalogView.UpgradeButton.Enabled = $false
            $shell.StatusLabel.Text = "$Action in progress"

            foreach ($application in @($plan.Unsupported)) {
                Write-KapselActivity -ActivityPanel $contextView.ActivityPanel -Message "Skipped $($application.Name): $provider is not supported." -Level Warning
            }

            foreach ($application in @($plan.Supported)) {
                Write-KapselActivity -ActivityPanel $contextView.ActivityPanel -Message "$Action $($application.Name) with $provider."
                [System.Windows.Forms.Application]::DoEvents()
                try {
                    $packageParameters = @{
                        Action         = $Action
                        Application    = $application
                        Provider       = $provider
                        ProviderStatus = $providerStatus
                        ProcessInvoker = $invokePackageProcess
                    }
                    $result = Invoke-KapselPackageAction @packageParameters
                    if ($result.Succeeded) {
                        $succeeded++
                        Write-KapselActivity -ActivityPanel $contextView.ActivityPanel -Message "Completed: $($application.Name)." -Level Success
                    }
                    else {
                        $failed++
                        Write-KapselActivity -ActivityPanel $contextView.ActivityPanel -Message "Failed: $($application.Name) returned exit code $($result.ExitCode)." -Level Error
                    }
                }
                catch {
                    $failed++
                    Write-KapselActivity -ActivityPanel $contextView.ActivityPanel -Message $_.Exception.Message -Level Error
                }
            }

            $shell.StatusLabel.Text = "$Action finished: $succeeded succeeded, $failed failed"
        }
        finally {
            $form.Cursor = [System.Windows.Forms.Cursors]::Default
            & $updateActionState
        }
    }

    $catalogView.RefreshButton.Add_Click($refreshCatalog)
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
    })
    $sidebar.ChocoButton.Add_Click({
        Write-KapselActivity -ActivityPanel $contextView.ActivityPanel -Message 'Package provider changed to choco.'
        & $updateActionState
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
    try {
        [void] $form.ShowDialog()
    }
    finally {
        [System.Windows.Forms.Application]::remove_ThreadException($threadExceptionHandler)
        $form.Dispose()
    }

    if ($null -ne $uiExceptionState.Exception) {
        throw "Unhandled UI error: $($uiExceptionState.Exception.Message)"
    }
}

Export-ModuleMember -Function 'Show-KapselGui'

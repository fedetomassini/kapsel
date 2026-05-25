# Kapsel Windows Forms composition root.
# UI sections live in focused modules; this file only wires state, events, and application flow.
Set-StrictMode -Version Latest

Import-Module (Join-Path $PSScriptRoot 'Applications.psm1') -Force
Import-Module (Join-Path $PSScriptRoot 'ApplicationGrid.psm1') -Force
Import-Module (Join-Path $PSScriptRoot 'ApplicationMain.psm1') -Force
Import-Module (Join-Path $PSScriptRoot 'ApplicationSidebar.psm1') -Force
Import-Module (Join-Path $PSScriptRoot 'Branding.psm1') -Force
Import-Module (Join-Path $PSScriptRoot 'UiTheme.psm1') -Force

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# Creates the main shell layout with sidebar, main content, and status bar.
function New-KapselShell {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [System.Windows.Forms.Control] $Sidebar,

        [Parameter(Mandatory = $true)]
        [System.Windows.Forms.Control] $Main,

        [Parameter(Mandatory = $true)]
        [System.Windows.Forms.Control] $Status
    )

    $colors = Get-KapselUiColors
    $shell = New-Object System.Windows.Forms.TableLayoutPanel
    $shell.Dock = [System.Windows.Forms.DockStyle]::Fill
    $shell.ColumnCount = 2
    $shell.RowCount = 2
    $shell.BackColor = $colors.Window
    [void] $shell.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Absolute, 270)))
    [void] $shell.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Percent, 100)))
    [void] $shell.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Percent, 100)))
    [void] $shell.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 34)))

    $shell.Controls.Add($Sidebar, 0, 0)
    $shell.Controls.Add($Main, 1, 0)
    $shell.Controls.Add($Status, 0, 1)
    $shell.SetColumnSpan($Status, 2)
    return $shell
}

function New-KapselStatusLabel {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [object] $Metadata
    )

    $colors = Get-KapselUiColors
    $statusLabel = New-Object System.Windows.Forms.Label
    $statusLabel.Text = "Ready - $($Metadata.Name) $($Metadata.Version) by $($Metadata.Creator)"
    $statusLabel.Dock = [System.Windows.Forms.DockStyle]::Fill
    $statusLabel.TextAlign = [System.Drawing.ContentAlignment]::MiddleLeft
    $statusLabel.Padding = New-Object System.Windows.Forms.Padding(16, 0, 0, 0)
    $statusLabel.BackColor = $colors.Status
    $statusLabel.ForeColor = $colors.Muted
    $statusLabel.Font = New-KapselFont -Size 8.5
    return $statusLabel
}

# Main function to show the Kapsel GUI, initialize state, and wire up events.
function Show-KapselGui {
    [CmdletBinding()]
    param()

    [System.Windows.Forms.Application]::EnableVisualStyles()
    Initialize-KapselUiTheme

    $metadata = Get-KapselMetadata
    $colors = Get-KapselUiColors
    $catalog = @(Get-KapselApplicationCatalog)
    $categories = @(Get-KapselApplicationCategory -Applications $catalog)
    $visibleCategories = @($categories | Where-Object { $_ -ne 'All' })
    $defaultCategory = if ($visibleCategories -contains 'Browsers') { 'Browsers' } elseif ($visibleCategories.Count -gt 0) { $visibleCategories[0] } else { 'All' }
    $selectedCategory = [PSCustomObject] @{ Value = $defaultCategory }
    $managerStatus = Get-KapselPackageManagerStatus

    $form = New-Object System.Windows.Forms.Form
    $form.Text = $metadata.Name
    $form.StartPosition = [System.Windows.Forms.FormStartPosition]::CenterScreen
    $form.MinimumSize = New-Object System.Drawing.Size(1180, 760)
    $form.Size = New-Object System.Drawing.Size(1360, 820)
    $form.BackColor = $colors.Window
    $form.Font = New-KapselFont -Size 9

    $sidebar = New-KapselSidebar -Metadata $metadata -Catalog $catalog -Categories $visibleCategories -DefaultCategory $defaultCategory -ManagerStatus $managerStatus
    $main = New-KapselMainContent -Metadata $metadata -Catalog $catalog -Categories $categories
    $statusLabel = New-KapselStatusLabel -Metadata $metadata
    $form.Controls.Add((New-KapselShell -Sidebar $sidebar.Panel -Main $main.Panel -Status $statusLabel))

    $refreshGrid = {
        $category = [string] $selectedCategory.Value
        $filtered = @(Search-KapselApplicationCatalog -Applications $catalog -Search $main.SearchBox.Text -Category $category -FossOnly:$main.FossOnly.Checked)
        Set-KapselApplicationGrid -Grid $main.Grid -Applications $filtered
        $main.Title.Text = if ($category -eq 'All') { 'All applications' } else { $category }
        $main.Description.Text = "Showing $($filtered.Count) application(s) from $category."
        $statusLabel.Text = "Showing $($filtered.Count) application(s) in $category - $($metadata.Name) $($metadata.Version)"
    }

    $runPackageAction = {
        param([string] $Action)

        $selected = @(Get-KapselSelectedApplications -Grid $main.Grid -Catalog $catalog)
        if ($selected.Count -eq 0) {
            [System.Windows.Forms.MessageBox]::Show('Select at least one application.', $metadata.Name) | Out-Null
            return
        }

        $provider = [string] $sidebar.ProviderCombo.SelectedItem
        $answer = [System.Windows.Forms.MessageBox]::Show(
            "$Action $($selected.Count) application(s) using $provider?",
            'Confirm package action',
            [System.Windows.Forms.MessageBoxButtons]::YesNo,
            [System.Windows.Forms.MessageBoxIcon]::Question
        )

        if ($answer -ne [System.Windows.Forms.DialogResult]::Yes) {
            return
        }

        try {
            $form.Cursor = [System.Windows.Forms.Cursors]::WaitCursor
            $statusLabel.Text = "$Action running"
            [System.Windows.Forms.Application]::DoEvents()

            foreach ($application in $selected) {
                Write-KapselLog -LogBox $main.LogBox -Message "$Action $($application.Name) with $provider"
                $result = Invoke-KapselPackageAction -Action $Action -Application $application -Provider $provider
                $state = if ($result.Succeeded) { 'OK' } else { "Exit $($result.ExitCode)" }
                Write-KapselLog -LogBox $main.LogBox -Message "$state - $($result.Command)"
            }

            $statusLabel.Text = 'Ready'
        }
        catch {
            $statusLabel.Text = 'Error'
            Write-KapselLog -LogBox $main.LogBox -Message $_.Exception.Message
            [System.Windows.Forms.MessageBox]::Show($_.Exception.Message, $metadata.Name) | Out-Null
        }
        finally {
            $form.Cursor = [System.Windows.Forms.Cursors]::Default
        }
    }

    $main.RefreshButton.Add_Click($refreshGrid)
    $main.SearchBox.Add_TextChanged($refreshGrid)
    $main.FossOnly.Add_CheckedChanged($refreshGrid)
    $sidebar.CategoryTree.Add_AfterSelect({
        if ($sidebar.CategoryTree.SelectedNode -ne $null -and $sidebar.CategoryTree.SelectedNode.Tag -ne $null) {
            $selectedCategory.Value = [string] $sidebar.CategoryTree.SelectedNode.Tag
            & $refreshGrid
        }
    })

    $main.SelectAllButton.Add_Click({
        foreach ($row in $main.Grid.Rows) {
            if (-not $row.IsNewRow) {
                $row.Cells['Selected'].Value = $true
            }
        }
    })

    $main.ClearButton.Add_Click({
        foreach ($row in $main.Grid.Rows) {
            if (-not $row.IsNewRow) {
                $row.Cells['Selected'].Value = $false
            }
        }
    })

    $main.InstallButton.Add_Click({ & $runPackageAction 'Install' })
    $main.UpgradeButton.Add_Click({ & $runPackageAction 'Upgrade' })

    $main.OpenLinkButton.Add_Click({
        if ($main.Grid.CurrentRow -eq $null) {
            return
        }

        $key = [string] $main.Grid.CurrentRow.Cells['Key'].Value
        $application = $catalog | Where-Object { $_.Key -eq $key } | Select-Object -First 1
        if ($application -and -not [string]::IsNullOrWhiteSpace($application.Link)) {
            Start-Process $application.Link
        }
    })

    & $refreshGrid
    Write-KapselLog -LogBox $main.LogBox -Message "$($metadata.Name) $($metadata.Version) by $($metadata.Creator)"
    Write-KapselLog -LogBox $main.LogBox -Message 'FOSS means Free and Open Source Software.'
    Write-KapselLog -LogBox $main.LogBox -Message "Loaded $($catalog.Count) application(s)."
    Write-KapselLog -LogBox $main.LogBox -Message "Package managers available - winget: $($managerStatus.WingetAvailable), choco: $($managerStatus.ChocoAvailable)"

    [void] $form.ShowDialog()
}

Export-ModuleMember -Function 'Show-KapselGui'

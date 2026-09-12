# Main catalog surface: summary, filters, grid, and package commands.
Set-StrictMode -Version Latest

Import-Module (Join-Path $PSScriptRoot 'ApplicationGridView.psm1') -Force
Import-Module (Join-Path $PSScriptRoot 'Theme.psm1') -Force

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

function New-KapselCatalogView {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)] [object] $Snapshot
    )

    $colors = Get-KapselUiColors
    $main = New-Object System.Windows.Forms.TableLayoutPanel
    $main.Dock = [System.Windows.Forms.DockStyle]::Fill
    $main.Padding = New-Object System.Windows.Forms.Padding(18, 14, 18, 12)
    $main.BackColor = $colors.Main
    $main.ColumnCount = 1
    $main.RowCount = 6
    [void] $main.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 58)))
    [void] $main.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 50)))
    [void] $main.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 54)))
    [void] $main.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 42)))
    [void] $main.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Percent, 100)))
    [void] $main.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 48)))

    $heading = New-Object System.Windows.Forms.Panel
    $heading.Dock = [System.Windows.Forms.DockStyle]::Fill
    $heading.BackColor = $colors.Main
    $title = New-KapselLabel -Text 'Applications' -Size 15 -Color $colors.Text -Style ([System.Drawing.FontStyle]::Bold) -Height 30
    $description = New-KapselLabel -Text 'Curated software ready to install or update.' -Size 8 -Color $colors.Muted -Height 22
    $heading.Controls.AddRange(@($description, $title))

    $metrics = New-Object System.Windows.Forms.TableLayoutPanel
    $metrics.Dock = [System.Windows.Forms.DockStyle]::Fill
    $metrics.BackColor = $colors.Main
    $metrics.ColumnCount = 5
    $metrics.RowCount = 1
    foreach ($index in 1..5) {
        [void] $metrics.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Percent, 20)))
    }
    $metricControls = @(
        (New-KapselMetric -Label 'Applications' -Value ([string] $Snapshot.Counts.Applications) -ValueColor $colors.Accent),
        (New-KapselMetric -Label 'Categories' -Value ([string] $Snapshot.Counts.Categories)),
        (New-KapselMetric -Label 'FOSS' -Value ([string] $Snapshot.Counts.Foss) -ValueColor $colors.Success),
        (New-KapselMetric -Label 'winget' -Value ([string] $Snapshot.Counts.Winget)),
        (New-KapselMetric -Label 'Chocolatey' -Value ([string] $Snapshot.Counts.Choco))
    )
    for ($index = 0; $index -lt $metricControls.Count; $index++) {
        $metricControls[$index].Dock = [System.Windows.Forms.DockStyle]::Fill
        $metricControls[$index].Margin = New-Object System.Windows.Forms.Padding(0, 0, 7, 0)
        $metrics.Controls.Add($metricControls[$index], $index, 0)
    }

    $filters = New-Object System.Windows.Forms.TableLayoutPanel
    $filters.Dock = [System.Windows.Forms.DockStyle]::Fill
    $filters.Padding = New-Object System.Windows.Forms.Padding(0, 9, 0, 9)
    $filters.BackColor = $colors.Main
    $filters.ColumnCount = 3
    $filters.RowCount = 1
    [void] $filters.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Percent, 100)))
    [void] $filters.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Absolute, 112)))
    [void] $filters.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Absolute, 100)))

    $searchBox = New-Object System.Windows.Forms.TextBox
    $searchBox.Dock = [System.Windows.Forms.DockStyle]::Fill
    $searchBox.BackColor = $colors.Surface
    $searchBox.ForeColor = $colors.Text
    $searchBox.BorderStyle = [System.Windows.Forms.BorderStyle]::FixedSingle
    $searchBox.Font = New-KapselFont -Size 8.5
    $searchBox.Margin = New-Object System.Windows.Forms.Padding(0, 0, 10, 0)
    Set-KapselTextBoxCueBanner -TextBox $searchBox -Text 'Search applications, categories, or package ids'

    $fossOnly = New-Object System.Windows.Forms.CheckBox
    $fossOnly.Text = 'FOSS only'
    $fossOnly.Dock = [System.Windows.Forms.DockStyle]::Fill
    $fossOnly.ForeColor = $colors.Muted
    $fossOnly.BackColor = $colors.Main
    $fossOnly.Font = New-KapselFont -Size 8
    $fossOnly.Margin = New-Object System.Windows.Forms.Padding(0)
    $fossOnly.Appearance = [System.Windows.Forms.Appearance]::Button
    $fossOnly.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $fossOnly.FlatAppearance.BorderColor = $colors.Border
    $fossOnly.FlatAppearance.CheckedBackColor = $colors.AccentDark
    $fossOnly.FlatAppearance.MouseOverBackColor = $colors.SurfaceAlt
    $fossOnly.TextAlign = [System.Drawing.ContentAlignment]::MiddleCenter
    $fossOnly.UseVisualStyleBackColor = $false
    $toolTip = New-Object System.Windows.Forms.ToolTip
    $toolTip.SetToolTip($fossOnly, 'Show only Free and Open Source Software.')

    $refreshButton = New-KapselButton -Text 'Refresh' -Width 92 -Icon 'Refresh'
    $refreshButton.Dock = [System.Windows.Forms.DockStyle]::Fill
    $refreshButton.Margin = New-Object System.Windows.Forms.Padding(8, 0, 0, 0)
    $filters.Controls.Add($searchBox, 0, 0)
    $filters.Controls.Add($fossOnly, 1, 0)
    $filters.Controls.Add($refreshButton, 2, 0)

    $inventoryFilters = New-Object System.Windows.Forms.TableLayoutPanel
    $inventoryFilters.Dock = [System.Windows.Forms.DockStyle]::Fill
    $inventoryFilters.Margin = New-Object System.Windows.Forms.Padding(0)
    $inventoryFilters.Padding = New-Object System.Windows.Forms.Padding(0, 4, 0, 6)
    $inventoryFilters.BackColor = $colors.Main
    $inventoryFilters.ColumnCount = 4
    $inventoryFilters.RowCount = 1
    foreach ($width in @(70, 112, 112)) {
        [void] $inventoryFilters.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Absolute, $width)))
    }
    [void] $inventoryFilters.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Percent, 100)))
    $allButton = New-KapselButton -Text 'All' -Width 68 -Icon 'All'
    $installedButton = New-KapselButton -Text 'Installed' -Width 110 -Icon 'Installed'
    $updatesButton = New-KapselButton -Text 'Updates' -Width 110 -Icon 'Updates'
    foreach ($button in @($allButton, $installedButton, $updatesButton)) {
        $button.Dock = [System.Windows.Forms.DockStyle]::Fill
        $button.Margin = New-Object System.Windows.Forms.Padding(0, 0, 6, 0)
    }
    $allButton.Name = 'KapselFilterAll'
    $installedButton.Name = 'KapselFilterInstalled'
    $updatesButton.Name = 'KapselFilterUpdates'
    $allButton.BackColor = $colors.AccentDark
    $allButton.ForeColor = $colors.Accent
    $allButton.FlatAppearance.BorderColor = $colors.Accent
    $inventorySummary = New-KapselLabel -Text 'Checking installed apps...' -Size 7.5 -Color $colors.Muted -Height 32 -Dock ([System.Windows.Forms.DockStyle]::Fill) -TextAlign ([System.Drawing.ContentAlignment]::MiddleRight)
    $inventoryFilters.Controls.Add($allButton, 0, 0)
    $inventoryFilters.Controls.Add($installedButton, 1, 0)
    $inventoryFilters.Controls.Add($updatesButton, 2, 0)
    $inventoryFilters.Controls.Add($inventorySummary, 3, 0)

    $grid = New-KapselApplicationGrid

    $actions = New-Object System.Windows.Forms.TableLayoutPanel
    $actions.Dock = [System.Windows.Forms.DockStyle]::Fill
    $actions.Padding = New-Object System.Windows.Forms.Padding(0, 8, 0, 0)
    $actions.BackColor = $colors.Main
    $actions.ColumnCount = 2
    $actions.RowCount = 1
    [void] $actions.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Percent, 100)))
    [void] $actions.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::AutoSize)))

    $selectionLabel = New-KapselLabel -Text '0 selected' -Size 8 -Color $colors.Muted -Height 32 -Dock ([System.Windows.Forms.DockStyle]::Fill)
    $actionButtons = New-Object System.Windows.Forms.FlowLayoutPanel
    $actionButtons.AutoSize = $true
    $actionButtons.WrapContents = $false
    $actionButtons.BackColor = $colors.Main
    $actionButtons.Dock = [System.Windows.Forms.DockStyle]::Right

    $selectAllButton = New-KapselButton -Text 'Select visible' -Width 120 -Icon 'Select'
    $clearButton = New-KapselButton -Text 'Clear' -Width 70 -Icon 'Clear'
    $openLinkButton = New-KapselButton -Text 'Website' -Width 84 -Icon 'Website'
    $upgradeButton = New-KapselButton -Text 'Update' -Width 84 -Icon 'Update'
    $installButton = New-KapselButton -Text 'Install' -Width 84 -Icon 'Install' -BackColor $colors.Accent -ForeColor $colors.Window -BorderColor $colors.Accent
    $actionButtons.Controls.AddRange(@($selectAllButton, $clearButton, $openLinkButton, $upgradeButton, $installButton))
    $actions.Controls.Add($selectionLabel, 0, 0)
    $actions.Controls.Add($actionButtons, 1, 0)

    $main.Controls.Add($heading, 0, 0)
    $main.Controls.Add($metrics, 0, 1)
    $main.Controls.Add($filters, 0, 2)
    $main.Controls.Add($inventoryFilters, 0, 3)
    $main.Controls.Add($grid, 0, 4)
    $main.Controls.Add($actions, 0, 5)

    return [PSCustomObject] @{
        Panel           = $main
        Title           = $title
        Description     = $description
        SearchBox       = $searchBox
        FossOnly        = $fossOnly
        RefreshButton   = $refreshButton
        AllButton       = $allButton
        InstalledButton = $installedButton
        UpdatesButton   = $updatesButton
        InventorySummary = $inventorySummary
        Grid            = $grid
        SelectionLabel  = $selectionLabel
        SelectAllButton = $selectAllButton
        ClearButton     = $clearButton
        OpenLinkButton  = $openLinkButton
        UpgradeButton   = $upgradeButton
        InstallButton   = $installButton
    }
}

Export-ModuleMember -Function 'New-KapselCatalogView'

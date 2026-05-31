# Main application section: title, stats, filters, actions, grid, and information tabs.
Set-StrictMode -Version Latest

Import-Module (Join-Path $PSScriptRoot 'ApplicationGrid.psm1') -Force
Import-Module (Join-Path $PSScriptRoot 'ApplicationInfo.psm1') -Force
Import-Module (Join-Path $PSScriptRoot 'UiTheme.psm1') -Force

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# Creates the main content panel with title, stats, filters, action buttons, application grid, and lower information tabs.
function New-KapselMainContent {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [object] $Metadata,

        [Parameter(Mandatory = $true)]
        [object[]] $Catalog,

        [Parameter(Mandatory = $true)]
        [string[]] $Categories
    )

    $colors = Get-KapselUiColors

    $main = New-Object System.Windows.Forms.TableLayoutPanel
    $main.Dock = [System.Windows.Forms.DockStyle]::Fill
    $main.Padding = New-Object System.Windows.Forms.Padding(22)
    $main.BackColor = $colors.Window
    $main.ColumnCount = 1
    $main.RowCount = 6
    [void] $main.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 62)))
    [void] $main.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 78)))
    [void] $main.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 58)))
    [void] $main.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 46)))
    [void] $main.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Percent, 100)))
    [void] $main.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 185)))

    $titlePanel = New-Object System.Windows.Forms.Panel
    $titlePanel.Dock = [System.Windows.Forms.DockStyle]::Fill
    $titlePanel.BackColor = $colors.Window

    $title = New-Object System.Windows.Forms.Label
    $title.Text = 'Applications'
    $title.Dock = [System.Windows.Forms.DockStyle]::Top
    $title.Height = 34
    $title.Font = New-KapselFont -Size 18 -Style ([System.Drawing.FontStyle]::Bold)
    $title.ForeColor = $colors.Text

    $description = New-Object System.Windows.Forms.Label
    $description.Text = 'Install and update curated applications with winget or Chocolatey.'
    $description.Dock = [System.Windows.Forms.DockStyle]::Top
    $description.Height = 22
    $description.Font = New-KapselFont -Size 9
    $description.ForeColor = $colors.Muted
    $titlePanel.Controls.AddRange(@($description, $title))

    $statsPanel = New-Object System.Windows.Forms.FlowLayoutPanel
    $statsPanel.Dock = [System.Windows.Forms.DockStyle]::Fill
    $statsPanel.BackColor = $colors.Window
    $statsPanel.WrapContents = $false
    $statsPanel.Controls.AddRange(@(
        (New-KapselStat -Title 'Applications' -Value ([string] $Catalog.Count)),
        (New-KapselStat -Title 'Categories' -Value ([string] (($Categories.Count) - 1))),
        (New-KapselStat -Title 'FOSS' -Value ([string] (@($Catalog | Where-Object { $_.Foss }).Count))),
        (New-KapselStat -Title 'winget packages' -Value ([string] (@($Catalog | Where-Object { $_.WingetId }).Count))),
        (New-KapselStat -Title 'choco packages' -Value ([string] (@($Catalog | Where-Object { $_.ChocoId }).Count)))
    ))

    $filterPanel = New-Object System.Windows.Forms.TableLayoutPanel
    $filterPanel.Dock = [System.Windows.Forms.DockStyle]::Fill
    $filterPanel.ColumnCount = 3
    $filterPanel.RowCount = 1
    $filterPanel.BackColor = $colors.Window
    [void] $filterPanel.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Percent, 100)))
    [void] $filterPanel.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Absolute, 118)))
    [void] $filterPanel.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Absolute, 126)))

    $searchPanel = New-Object System.Windows.Forms.Panel
    $searchPanel.Dock = [System.Windows.Forms.DockStyle]::Fill
    $searchPanel.BackColor = $colors.Window

    $searchBox = New-Object System.Windows.Forms.TextBox
    $searchBox.Dock = [System.Windows.Forms.DockStyle]::Bottom
    $searchBox.Height = 26
    $searchBox.BackColor = $colors.Surface
    $searchBox.ForeColor = $colors.Text
    $searchBox.BorderStyle = [System.Windows.Forms.BorderStyle]::FixedSingle
    $searchBox.Font = New-KapselFont -Size 9
    $searchPanel.Controls.Add($searchBox)
    $searchPanel.Controls.Add((New-KapselSectionLabel -Text 'Search'))

    $fossPanel = New-Object System.Windows.Forms.Panel
    $fossPanel.Dock = [System.Windows.Forms.DockStyle]::Fill
    $fossPanel.BackColor = $colors.Window
    $fossOnly = New-Object System.Windows.Forms.CheckBox
    $fossOnly.Text = 'FOSS only'
    $fossOnly.Dock = [System.Windows.Forms.DockStyle]::Bottom
    $fossOnly.Height = 28
    $fossOnly.ForeColor = $colors.Text
    $fossOnly.Font = New-KapselFont -Size 9
    $fossPanel.Controls.Add($fossOnly)
    $fossPanel.Controls.Add((New-KapselSectionLabel -Text 'License'))

    $toolTip = New-Object System.Windows.Forms.ToolTip
    $toolTip.SetToolTip($fossOnly, 'FOSS means Free and Open Source Software: source code is publicly available under an open license.')

    $refreshPanel = New-Object System.Windows.Forms.Panel
    $refreshPanel.Dock = [System.Windows.Forms.DockStyle]::Fill
    $refreshPanel.BackColor = $colors.Window
    $refreshButton = New-KapselButton -Text 'Refresh'
    $refreshButton.Dock = [System.Windows.Forms.DockStyle]::Bottom
    $refreshPanel.Controls.Add($refreshButton)
    $refreshPanel.Controls.Add((New-KapselSectionLabel -Text 'Catalog'))

    $filterPanel.Controls.Add($searchPanel, 0, 0)
    $filterPanel.Controls.Add($fossPanel, 1, 0)
    $filterPanel.Controls.Add($refreshPanel, 2, 0)

    $actionsPanel = New-Object System.Windows.Forms.FlowLayoutPanel
    $actionsPanel.Dock = [System.Windows.Forms.DockStyle]::Fill
    $actionsPanel.BackColor = $colors.Window
    $actionsPanel.WrapContents = $false
    $selectAllButton = New-KapselButton -Text 'Select visible'
    $clearButton = New-KapselButton -Text 'Clear selection'
    $installButton = New-KapselButton -Text 'Install selected' -BackColor $colors.AccentDark
    $upgradeButton = New-KapselButton -Text 'Update selected' -BackColor $colors.Warning
    $openLinkButton = New-KapselButton -Text 'Open website'
    $actionsPanel.Controls.AddRange(@($selectAllButton, $clearButton, $installButton, $upgradeButton, $openLinkButton))

    $grid = New-KapselApplicationGrid
    $infoSection = New-KapselInfoSection -Metadata $Metadata

    $main.Controls.Add($titlePanel, 0, 0)
    $main.Controls.Add($statsPanel, 0, 1)
    $main.Controls.Add($filterPanel, 0, 2)
    $main.Controls.Add($actionsPanel, 0, 3)
    $main.Controls.Add($grid, 0, 4)
    $main.Controls.Add($infoSection.Panel, 0, 5)

    return [PSCustomObject] @{
        Panel           = $main
        Title           = $title
        Description     = $description
        SearchBox       = $searchBox
        FossOnly        = $fossOnly
        RefreshButton   = $refreshButton
        SelectAllButton = $selectAllButton
        ClearButton     = $clearButton
        InstallButton   = $installButton
        UpgradeButton   = $upgradeButton
        OpenLinkButton  = $openLinkButton
        Grid            = $grid
        LogBox          = $infoSection.LogBox
    }
}

Export-ModuleMember -Function 'New-KapselMainContent'

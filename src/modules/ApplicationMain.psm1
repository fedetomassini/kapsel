# Main application section: title, stats, filters, actions, grid, and information tabs.
Set-StrictMode -Version Latest

Import-Module (Join-Path $PSScriptRoot 'ApplicationGrid.psm1') -Force
Import-Module (Join-Path $PSScriptRoot 'ApplicationInfo.psm1') -Force
Import-Module (Join-Path $PSScriptRoot 'UiTheme.psm1') -Force

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

function New-KapselFilterBox {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string] $Label,
        [Parameter(Mandatory = $true)]
        [System.Windows.Forms.Control] $Control
    )

    $colors = Get-KapselUiColors
    $panel = New-Object System.Windows.Forms.Panel
    $panel.Dock = [System.Windows.Forms.DockStyle]::Fill
    $panel.BackColor = $colors.Surface
    $panel.Padding = New-Object System.Windows.Forms.Padding(12, 8, 12, 10)
    $Control.Dock = [System.Windows.Forms.DockStyle]::Bottom
    $panel.Controls.Add($Control)
    $panel.Controls.Add((New-KapselSectionLabel -Text $Label))
    return $panel
}

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
    $main.Padding = New-Object System.Windows.Forms.Padding(24, 22, 24, 20)
    $main.BackColor = $colors.Window
    $main.ColumnCount = 1
    $main.RowCount = 6
    [void] $main.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 72)))
    [void] $main.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 82)))
    [void] $main.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 74)))
    [void] $main.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 48)))
    [void] $main.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Percent, 100)))
    [void] $main.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 190)))

    $titlePanel = New-Object System.Windows.Forms.Panel
    $titlePanel.Dock = [System.Windows.Forms.DockStyle]::Fill
    $titlePanel.BackColor = $colors.Window

    $title = New-KapselTextLabel -Text 'Applications' -Size 20 -Color $colors.Text -Style ([System.Drawing.FontStyle]::Bold) -Height 38
    $description = New-KapselTextLabel -Text 'Install and update curated Windows applications with a controlled package-manager workflow.' -Size 9 -Color $colors.Muted -Height 24
    $titlePanel.Controls.AddRange(@($description, $title))

    $statsPanel = New-Object System.Windows.Forms.FlowLayoutPanel
    $statsPanel.Dock = [System.Windows.Forms.DockStyle]::Fill
    $statsPanel.BackColor = $colors.Window
    $statsPanel.WrapContents = $false
    $statsPanel.Controls.AddRange(@(
        (New-KapselStat -Title 'Applications' -Value ([string] $Catalog.Count) -AccentColor $colors.Accent),
        (New-KapselStat -Title 'Categories' -Value ([string] (($Categories.Count) - 1)) -AccentColor $colors.AccentBlue),
        (New-KapselStat -Title 'FOSS' -Value ([string] (@($Catalog | Where-Object { $_.Foss }).Count)) -AccentColor $colors.Accent),
        (New-KapselStat -Title 'winget' -Value ([string] (@($Catalog | Where-Object { $_.WingetId }).Count)) -AccentColor $colors.Warning),
        (New-KapselStat -Title 'Chocolatey' -Value ([string] (@($Catalog | Where-Object { $_.ChocoId }).Count)) -AccentColor $colors.SurfaceSoft)
    ))

    $filterCard = New-KapselCard -Dock ([System.Windows.Forms.DockStyle]::Fill) -Padding (New-Object System.Windows.Forms.Padding(10))
    $filterGrid = New-Object System.Windows.Forms.TableLayoutPanel
    $filterGrid.Dock = [System.Windows.Forms.DockStyle]::Fill
    $filterGrid.BackColor = $colors.Surface
    $filterGrid.ColumnCount = 3
    $filterGrid.RowCount = 1
    [void] $filterGrid.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Percent, 100)))
    [void] $filterGrid.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Absolute, 150)))
    [void] $filterGrid.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Absolute, 136)))

    $searchBox = New-Object System.Windows.Forms.TextBox
    $searchBox.Height = 30
    $searchBox.BackColor = $colors.SurfaceAlt
    $searchBox.ForeColor = $colors.Text
    $searchBox.BorderStyle = [System.Windows.Forms.BorderStyle]::FixedSingle
    $searchBox.Font = New-KapselFont -Size 9

    $fossOnly = New-Object System.Windows.Forms.CheckBox
    $fossOnly.Text = 'FOSS only'
    $fossOnly.Height = 30
    $fossOnly.ForeColor = $colors.Text
    $fossOnly.Font = New-KapselFont -Size 9
    $fossOnly.BackColor = $colors.Surface

    $toolTip = New-Object System.Windows.Forms.ToolTip
    $toolTip.SetToolTip($fossOnly, 'FOSS means Free and Open Source Software: source code is publicly available under an open license.')

    $refreshButton = New-KapselButton -Text 'Refresh' -Width 116
    $refreshButton.Height = 30

    $filterGrid.Controls.Add((New-KapselFilterBox -Label 'Search catalog' -Control $searchBox), 0, 0)
    $filterGrid.Controls.Add((New-KapselFilterBox -Label 'License' -Control $fossOnly), 1, 0)
    $filterGrid.Controls.Add((New-KapselFilterBox -Label 'Data' -Control $refreshButton), 2, 0)
    $filterCard.Controls.Add($filterGrid)

    $actionsPanel = New-Object System.Windows.Forms.FlowLayoutPanel
    $actionsPanel.Dock = [System.Windows.Forms.DockStyle]::Fill
    $actionsPanel.BackColor = $colors.Window
    $actionsPanel.WrapContents = $false
    $selectAllButton = New-KapselButton -Text 'Select visible' -Width 134
    $clearButton = New-KapselButton -Text 'Clear selection' -Width 140
    $installButton = New-KapselButton -Text 'Install selected' -BackColor $colors.AccentDark -Width 144
    $upgradeButton = New-KapselButton -Text 'Update selected' -BackColor $colors.Warning -Width 144
    $openLinkButton = New-KapselButton -Text 'Open website' -Width 132
    $actionsPanel.Controls.AddRange(@($selectAllButton, $clearButton, $installButton, $upgradeButton, $openLinkButton))

    $grid = New-KapselApplicationGrid
    $infoSection = New-KapselInfoSection -Metadata $Metadata

    $main.Controls.Add($titlePanel, 0, 0)
    $main.Controls.Add($statsPanel, 0, 1)
    $main.Controls.Add($filterCard, 0, 2)
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

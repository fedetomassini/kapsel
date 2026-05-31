# Sidebar section: brand, provider selector, catalog info, and categories.
Set-StrictMode -Version Latest

Import-Module (Join-Path $PSScriptRoot 'UiTheme.psm1') -Force

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# Creates the sidebar panel with branding, provider selection, catalog info, and category tree.
function New-KapselSidebar {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [object] $Metadata,

        [Parameter(Mandatory = $true)]
        [object[]] $Catalog,

        [Parameter(Mandatory = $true)]
        [string[]] $Categories,

        [Parameter(Mandatory = $true)]
        [string] $DefaultCategory,

        [Parameter(Mandatory = $true)]
        [object] $ManagerStatus
    )

    $colors = Get-KapselUiColors

    $sidebar = New-Object System.Windows.Forms.Panel
    $sidebar.Dock = [System.Windows.Forms.DockStyle]::Fill
    $sidebar.Padding = New-Object System.Windows.Forms.Padding(18, 18, 18, 12)
    $sidebar.BackColor = $colors.Sidebar

    $brand = New-Object System.Windows.Forms.Label
    $brand.Text = $Metadata.Name
    $brand.Dock = [System.Windows.Forms.DockStyle]::Top
    $brand.Height = 42
    $brand.Font = New-KapselFont -Size 20 -Style ([System.Drawing.FontStyle]::Bold)
    $brand.ForeColor = $colors.Text

    $subtitle = New-Object System.Windows.Forms.Label
    $subtitle.Text = $Metadata.Description
    $subtitle.Dock = [System.Windows.Forms.DockStyle]::Top
    $subtitle.Height = 26
    $subtitle.Font = New-KapselFont -Size 9
    $subtitle.ForeColor = $colors.Muted

    $providerLabel = New-Object System.Windows.Forms.Label
    $providerLabel.Text = 'Provider'
    $providerLabel.Dock = [System.Windows.Forms.DockStyle]::Top
    $providerLabel.Height = 22
    $providerLabel.Margin = New-Object System.Windows.Forms.Padding(0, 24, 0, 0)
    $providerLabel.ForeColor = $colors.Muted
    $providerLabel.Font = New-KapselFont -Size 9

    $providerCombo = New-Object System.Windows.Forms.ComboBox
    $providerCombo.Dock = [System.Windows.Forms.DockStyle]::Top
    $providerCombo.DropDownStyle = [System.Windows.Forms.ComboBoxStyle]::DropDownList
    $providerCombo.BackColor = $colors.Surface
    $providerCombo.ForeColor = $colors.Text
    $providerCombo.Font = New-KapselFont -Size 9
    [void] $providerCombo.Items.Add('winget')
    [void] $providerCombo.Items.Add('choco')
    $providerCombo.SelectedItem = if ($ManagerStatus.WingetAvailable) { 'winget' } elseif ($ManagerStatus.ChocoAvailable) { 'choco' } else { 'winget' }

    $managerLabel = New-Object System.Windows.Forms.Label
    $managerLabel.Dock = [System.Windows.Forms.DockStyle]::Top
    $managerLabel.Height = 44
    $managerLabel.ForeColor = $colors.Muted
    $managerLabel.Font = New-KapselFont -Size 8
    $managerLabel.Text = "winget: $($ManagerStatus.WingetAvailable)`r`nchoco: $($ManagerStatus.ChocoAvailable)"

    $infoPanel = New-Object System.Windows.Forms.Panel
    $infoPanel.Dock = [System.Windows.Forms.DockStyle]::Top
    $infoPanel.Height = 224
    $infoPanel.Margin = New-Object System.Windows.Forms.Padding(0, 18, 0, 0)
    $infoPanel.BackColor = $colors.Surface

    $infoTitle = New-Object System.Windows.Forms.Label
    $infoTitle.Text = 'About'
    $infoTitle.Left = 12
    $infoTitle.Top = 10
    $infoTitle.Width = 210
    $infoTitle.Height = 22
    $infoTitle.Font = New-KapselFont -Size 10 -Style ([System.Drawing.FontStyle]::Bold)
    $infoTitle.ForeColor = $colors.Text

    $infoText = New-Object System.Windows.Forms.Label
    $infoText.Left = 12
    $infoText.Top = 38
    $infoText.Width = 210
    $infoText.Height = 176
    $infoText.Font = New-KapselFont -Size 8
    $infoText.ForeColor = $colors.Muted
    $infoText.Text = @(
        "Version: $($Metadata.Version)",
        "Creator: $($Metadata.Creator)",
        '',
        'Catalog: src/applications.json',
        "Applications: $($Catalog.Count)",
        '',
        'FOSS means Free and Open Source Software: apps whose source code is publicly available and can usually be studied, modified, and redistributed under their license.',
        '',
        "$($Metadata.Name) delegates installs and updates to winget or Chocolatey."
    ) -join [Environment]::NewLine

    $infoPanel.Controls.AddRange(@($infoTitle, $infoText))

    $categoryLabel = New-Object System.Windows.Forms.Label
    $categoryLabel.Text = 'Categories'
    $categoryLabel.Dock = [System.Windows.Forms.DockStyle]::Top
    $categoryLabel.Height = 22
    $categoryLabel.Margin = New-Object System.Windows.Forms.Padding(0, 16, 0, 0)
    $categoryLabel.ForeColor = $colors.Muted
    $categoryLabel.Font = New-KapselFont -Size 9

    $categoryTree = New-Object System.Windows.Forms.TreeView
    $categoryTree.Dock = [System.Windows.Forms.DockStyle]::Top
    $categoryTree.Height = 274
    $categoryTree.BackColor = $colors.Surface
    $categoryTree.ForeColor = $colors.Text
    $categoryTree.BorderStyle = [System.Windows.Forms.BorderStyle]::FixedSingle
    $categoryTree.Font = New-KapselFont -Size 8.5
    $categoryTree.HideSelection = $false
    $categoryTree.ShowLines = $false
    $categoryTree.ShowPlusMinus = $false
    $categoryTree.ShowRootLines = $false

    $allNode = New-Object System.Windows.Forms.TreeNode("All applications ({0})" -f $Catalog.Count)
    $allNode.Tag = 'All'
    [void] $categoryTree.Nodes.Add($allNode)

    foreach ($category in $Categories) {
        $count = @($Catalog | Where-Object { $_.Category -eq $category }).Count
        $node = New-Object System.Windows.Forms.TreeNode("{0} ({1})" -f $category, $count)
        $node.Tag = $category
        [void] $categoryTree.Nodes.Add($node)

        if ($category -eq $DefaultCategory) {
            $categoryTree.SelectedNode = $node
        }
    }

    $sidebar.Controls.AddRange(@($categoryTree, $categoryLabel, $infoPanel, $managerLabel, $providerCombo, $providerLabel, $subtitle, $brand))

    return [PSCustomObject] @{
        Panel         = $sidebar
        ProviderCombo = $providerCombo
        CategoryTree  = $categoryTree
    }
}

Export-ModuleMember -Function 'New-KapselSidebar'


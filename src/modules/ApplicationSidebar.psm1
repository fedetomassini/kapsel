# Sidebar section: brand, provider selector, catalog info, and categories.
Set-StrictMode -Version Latest

Import-Module (Join-Path $PSScriptRoot 'Assets.psm1') -Force
Import-Module (Join-Path $PSScriptRoot 'UiTheme.psm1') -Force

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

function Add-KapselAboutLine {
    param(
        [System.Windows.Forms.Control] $Panel,
        [string] $Text,
        [bool] $Strong = $false
    )

    $colors = Get-KapselUiColors
    $style = if ($Strong) { [System.Drawing.FontStyle]::Bold } else { [System.Drawing.FontStyle]::Regular }
    $color = if ($Strong) { $colors.Text } else { $colors.Muted }
    $label = New-KapselTextLabel -Text $Text -Size 8 -Color $color -Style $style -Height 21 -Dock ([System.Windows.Forms.DockStyle]::Top)
    $Panel.Controls.Add($label)
}

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

    $sidebar = New-Object System.Windows.Forms.TableLayoutPanel
    $sidebar.Dock = [System.Windows.Forms.DockStyle]::Fill
    $sidebar.Padding = New-Object System.Windows.Forms.Padding(18)
    $sidebar.BackColor = $colors.Sidebar
    $sidebar.ColumnCount = 1
    $sidebar.RowCount = 5
    [void] $sidebar.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 82)))
    [void] $sidebar.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 120)))
    [void] $sidebar.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 182)))
    [void] $sidebar.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 30)))
    [void] $sidebar.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Percent, 100)))

    $brandPanel = New-Object System.Windows.Forms.TableLayoutPanel
    $brandPanel.Dock = [System.Windows.Forms.DockStyle]::Fill
    $brandPanel.BackColor = $colors.Sidebar
    $brandPanel.ColumnCount = 2
    $brandPanel.RowCount = 1
    [void] $brandPanel.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Absolute, 58)))
    [void] $brandPanel.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Percent, 100)))

    $logo = New-KapselLogoView -LogoPath (Get-KapselLogoPath) -Size 48
    $logo.Margin = New-Object System.Windows.Forms.Padding(0, 2, 10, 0)

    $brandText = New-Object System.Windows.Forms.Panel
    $brandText.Dock = [System.Windows.Forms.DockStyle]::Fill
    $brandText.BackColor = $colors.Sidebar
    $brand = New-KapselTextLabel -Text $Metadata.Name -Size 19 -Color $colors.Text -Style ([System.Drawing.FontStyle]::Bold) -Height 34
    $subtitle = New-KapselTextLabel -Text $Metadata.Description -Size 8.5 -Color $colors.Muted -Height 22
    $brandText.Controls.AddRange(@($subtitle, $brand))
    $brandPanel.Controls.Add($logo, 0, 0)
    $brandPanel.Controls.Add($brandText, 1, 0)

    $providerCard = New-KapselCard -Dock ([System.Windows.Forms.DockStyle]::Fill) -Padding (New-Object System.Windows.Forms.Padding(12))
    $providerTitle = New-KapselTextLabel -Text 'Package provider' -Size 9 -Color $colors.Text -Style ([System.Drawing.FontStyle]::Bold) -Height 24
    $providerHint = New-KapselTextLabel -Text 'Select the backend used for install and update actions.' -Size 8 -Color $colors.Muted -Height 24

    $providerCombo = New-Object System.Windows.Forms.ComboBox
    $providerCombo.Dock = [System.Windows.Forms.DockStyle]::Top
    $providerCombo.Height = 28
    $providerCombo.DropDownStyle = [System.Windows.Forms.ComboBoxStyle]::DropDownList
    $providerCombo.BackColor = $colors.SurfaceAlt
    $providerCombo.ForeColor = $colors.Text
    $providerCombo.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $providerCombo.Font = New-KapselFont -Size 9
    [void] $providerCombo.Items.Add('winget')
    [void] $providerCombo.Items.Add('choco')
    $providerCombo.SelectedItem = if ($ManagerStatus.WingetAvailable) { 'winget' } elseif ($ManagerStatus.ChocoAvailable) { 'choco' } else { 'winget' }

    $badges = New-Object System.Windows.Forms.FlowLayoutPanel
    $badges.Dock = [System.Windows.Forms.DockStyle]::Bottom
    $badges.Height = 28
    $badges.BackColor = $colors.Surface
    $badges.WrapContents = $false
    $badges.Controls.AddRange(@(
        (New-KapselBadge -Text 'winget' -Enabled ([bool] $ManagerStatus.WingetAvailable)),
        (New-KapselBadge -Text 'choco' -Enabled ([bool] $ManagerStatus.ChocoAvailable))
    ))

    $providerCard.Controls.AddRange(@($badges, $providerCombo, $providerHint, $providerTitle))

    $aboutCard = New-KapselCard -Dock ([System.Windows.Forms.DockStyle]::Fill) -Padding (New-Object System.Windows.Forms.Padding(12))
    Add-KapselAboutLine -Panel $aboutCard -Text 'About' -Strong $true
    Add-KapselAboutLine -Panel $aboutCard -Text "Version: $($Metadata.Version)"
    Add-KapselAboutLine -Panel $aboutCard -Text "Creator: $($Metadata.Creator)"
    Add-KapselAboutLine -Panel $aboutCard -Text "Applications: $($Catalog.Count)"
    Add-KapselAboutLine -Panel $aboutCard -Text 'Catalog: src/applications.json'
    Add-KapselAboutLine -Panel $aboutCard -Text 'FOSS means Free and Open Source Software.'
    Add-KapselAboutLine -Panel $aboutCard -Text 'Installs and updates are delegated to package managers.'

    $categoryLabel = New-KapselTextLabel -Text 'Categories' -Size 9 -Color $colors.Text -Style ([System.Drawing.FontStyle]::Bold) -Height 26

    $categoryTree = New-Object System.Windows.Forms.TreeView
    $categoryTree.Dock = [System.Windows.Forms.DockStyle]::Fill
    $categoryTree.BackColor = $colors.Surface
    $categoryTree.ForeColor = $colors.Text
    $categoryTree.BorderStyle = [System.Windows.Forms.BorderStyle]::None
    $categoryTree.Font = New-KapselFont -Size 8.5
    $categoryTree.HideSelection = $false
    $categoryTree.ShowLines = $false
    $categoryTree.ShowPlusMinus = $false
    $categoryTree.ShowRootLines = $false
    $categoryTree.ItemHeight = 28

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

    if ($null -eq $categoryTree.SelectedNode) {
        $categoryTree.SelectedNode = $allNode
    }

    $sidebar.Controls.Add($brandPanel, 0, 0)
    $sidebar.Controls.Add($providerCard, 0, 1)
    $sidebar.Controls.Add($aboutCard, 0, 2)
    $sidebar.Controls.Add($categoryLabel, 0, 3)
    $sidebar.Controls.Add($categoryTree, 0, 4)

    return [PSCustomObject] @{
        Panel         = $sidebar
        ProviderCombo = $providerCombo
        CategoryTree  = $categoryTree
    }
}

Export-ModuleMember -Function 'New-KapselSidebar'

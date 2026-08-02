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

function New-KapselProviderOption {
    param(
        [Parameter(Mandatory = $true)]
        [string] $Text,

        [Parameter(Mandatory = $true)]
        [bool] $Available
    )

    $colors = Get-KapselUiColors
    $option = New-Object System.Windows.Forms.Button
    $option.Text = $Text
    $option.Tag = $Text
    $option.Width = 112
    $option.Height = 34
    $option.Margin = New-Object System.Windows.Forms.Padding(0, 0, 8, 0)
    $option.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $option.FlatAppearance.MouseOverBackColor = $colors.SurfaceSoft
    $option.FlatAppearance.MouseDownBackColor = $colors.AccentDark
    $option.Font = New-KapselFont -Size 8.5
    $option.TextAlign = [System.Drawing.ContentAlignment]::MiddleCenter
    $option.Enabled = $Available
    return $option
}

function Set-KapselProviderOptionState {
    param(
        [Parameter(Mandatory = $true)]
        [System.Windows.Forms.Button] $Button,

        [Parameter(Mandatory = $true)]
        [bool] $Active,

        [Parameter(Mandatory = $true)]
        [bool] $Available
    )

    $colors = Get-KapselUiColors
    $Button.BackColor = if ($Active) { $colors.AccentDark } elseif ($Available) { $colors.SurfaceAlt } else { $colors.Surface }
    $Button.ForeColor = if ($Available) { $colors.Text } else { $colors.Muted }
    $Button.FlatAppearance.BorderColor = if ($Active) { $colors.Accent } else { $colors.Border }
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
    [void] $sidebar.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 96)))
    [void] $sidebar.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 182)))
    [void] $sidebar.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 30)))
    [void] $sidebar.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Percent, 100)))

    $brandPanel = New-Object System.Windows.Forms.TableLayoutPanel
    $brandPanel.Dock = [System.Windows.Forms.DockStyle]::Fill
    $brandPanel.BackColor = $colors.Sidebar
    $brandPanel.RowCount = 1

    $brandText = New-Object System.Windows.Forms.Panel
    $brandText.Dock = [System.Windows.Forms.DockStyle]::Fill
    $brandText.BackColor = $colors.Sidebar
    $brand = New-KapselTextLabel -Text $Metadata.Name -Size 19 -Color $colors.Text -Style ([System.Drawing.FontStyle]::Bold) -Height 34
    $subtitle = New-KapselTextLabel -Text $Metadata.Description -Size 8.5 -Color $colors.Muted -Height 22
    $brandText.Controls.AddRange(@($subtitle, $brand))

    $brandImage = New-KapselBrandImageView -ImagePath (Get-KapselBrandImagePath) -Size 48
    if ($null -ne $brandImage) {
        $brandPanel.ColumnCount = 2
        [void] $brandPanel.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Absolute, 58)))
        [void] $brandPanel.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Percent, 100)))
        $brandImage.Margin = New-Object System.Windows.Forms.Padding(0, 2, 10, 0)
        $brandPanel.Controls.Add($brandImage, 0, 0)
        $brandPanel.Controls.Add($brandText, 1, 0)
    }
    else {
        $brandPanel.ColumnCount = 1
        [void] $brandPanel.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Percent, 100)))
        $brandPanel.Controls.Add($brandText, 0, 0)
    }

    $providerCard = New-KapselCard -Dock ([System.Windows.Forms.DockStyle]::Fill) -Padding (New-Object System.Windows.Forms.Padding(12))
    $providerTitle = New-KapselTextLabel -Text 'Package provider' -Size 9 -Color $colors.Text -Style ([System.Drawing.FontStyle]::Bold) -Height 24
    $providerHint = New-KapselTextLabel -Text 'Select the backend used for install and update actions.' -Size 8 -Color $colors.Muted -Height 24

    $selectedProvider = if ($ManagerStatus.WingetAvailable) { 'winget' } elseif ($ManagerStatus.ChocoAvailable) { 'choco' } else { $null }
    $providerState = [PSCustomObject] @{ Value = $selectedProvider }

    $providerOptions = New-Object System.Windows.Forms.FlowLayoutPanel
    $providerOptions.Dock = [System.Windows.Forms.DockStyle]::Top
    $providerOptions.Height = 40
    $providerOptions.BackColor = $colors.Surface
    $providerOptions.WrapContents = $false

    $wingetOption = New-KapselProviderOption -Text 'winget' -Available ([bool] $ManagerStatus.WingetAvailable)
    $chocoOption = New-KapselProviderOption -Text 'choco' -Available ([bool] $ManagerStatus.ChocoAvailable)

    $setProvider = {
        param([AllowNull()] [string] $Provider)

        $isWinget = $Provider -eq 'winget' -and $ManagerStatus.WingetAvailable
        $isChoco = $Provider -eq 'choco' -and $ManagerStatus.ChocoAvailable
        $providerState.Value = if ($isWinget) { 'winget' } elseif ($isChoco) { 'choco' } else { $null }
        Set-KapselProviderOptionState -Button $wingetOption -Active ($providerState.Value -eq 'winget') -Available ([bool] $ManagerStatus.WingetAvailable)
        Set-KapselProviderOptionState -Button $chocoOption -Active ($providerState.Value -eq 'choco') -Available ([bool] $ManagerStatus.ChocoAvailable)
    }

    $wingetOption.Add_Click({ & $setProvider 'winget' })
    $chocoOption.Add_Click({ & $setProvider 'choco' })
    & $setProvider $selectedProvider
    $providerOptions.Controls.AddRange(@($wingetOption, $chocoOption))

    $providerCard.Controls.AddRange(@($providerOptions, $providerHint, $providerTitle))

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
    $categoryTree.ItemHeight = 30
    Set-KapselDarkTreeView -TreeView $categoryTree

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
        ProviderState = $providerState
        CategoryTree  = $categoryTree
    }
}

Export-ModuleMember -Function 'New-KapselSidebar'


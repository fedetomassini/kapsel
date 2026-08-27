# Left navigation surface: product identity, package provider, and categories.
Set-StrictMode -Version Latest

Import-Module (Join-Path $PSScriptRoot 'Theme.psm1') -Force

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

function New-KapselProviderButton {
    param(
        [Parameter(Mandatory = $true)] [string] $Provider,
        [Parameter(Mandatory = $true)] [bool] $Available
    )

    $button = New-KapselButton -Text $Provider -Width 102
    $button.Tag = $Provider
    $button.Enabled = $Available
    return $button
}

function Set-KapselProviderButtonState {
    param(
        [Parameter(Mandatory = $true)] [System.Windows.Forms.Button] $Button,
        [Parameter(Mandatory = $true)] [bool] $Active,
        [Parameter(Mandatory = $true)] [bool] $Available
    )

    $colors = Get-KapselUiColors
    $Button.BackColor = if ($Active) { $colors.AccentDark } elseif ($Available) { $colors.Surface } else { $colors.Sidebar }
    $Button.ForeColor = if ($Active) { $colors.Accent } elseif ($Available) { $colors.Text } else { $colors.Subtle }
    $Button.FlatAppearance.BorderColor = if ($Active) { $colors.Accent } else { $colors.Border }
}

function New-KapselSidebarView {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)] [object] $Metadata,
        [object[]] $Catalog = @(),
        [string[]] $Categories = @(),
        [Parameter(Mandatory = $true)] [string] $DefaultCategory,
        [Parameter(Mandatory = $true)] [object] $ProviderStatus,
        [AllowNull()] [string] $BrandImagePath
    )

    $colors = Get-KapselUiColors
    $sidebar = New-Object System.Windows.Forms.TableLayoutPanel
    $sidebar.Dock = [System.Windows.Forms.DockStyle]::Fill
    $sidebar.Padding = New-Object System.Windows.Forms.Padding(12, 14, 12, 10)
    $sidebar.BackColor = $colors.Sidebar
    $sidebar.ColumnCount = 1
    $sidebar.RowCount = 7
    [void] $sidebar.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 62)))
    [void] $sidebar.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 24)))
    [void] $sidebar.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 42)))
    [void] $sidebar.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 26)))
    [void] $sidebar.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Percent, 100)))
    [void] $sidebar.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 24)))
    [void] $sidebar.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 70)))

    $brand = New-Object System.Windows.Forms.TableLayoutPanel
    $brand.Dock = [System.Windows.Forms.DockStyle]::Fill
    $brand.BackColor = $colors.Sidebar
    $brand.RowCount = 1
    $brandImage = New-KapselBrandImageView -ImagePath $BrandImagePath -Size 38
    $brandText = New-Object System.Windows.Forms.Panel
    $brandText.Dock = [System.Windows.Forms.DockStyle]::Fill
    $brandText.BackColor = $colors.Sidebar
    $nameLabel = New-KapselLabel -Text $Metadata.Name.ToUpperInvariant() -Size 14 -Color $colors.Text -Style ([System.Drawing.FontStyle]::Bold) -Height 30
    $descriptionLabel = New-KapselLabel -Text 'Application catalog' -Size 7.5 -Color $colors.Muted -Height 20
    $brandText.Controls.AddRange(@($descriptionLabel, $nameLabel))

    if ($null -ne $brandImage) {
        $brand.ColumnCount = 2
        [void] $brand.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Absolute, 48)))
        [void] $brand.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Percent, 100)))
        $brandImage.Margin = New-Object System.Windows.Forms.Padding(0, 3, 8, 0)
        $brand.Controls.Add($brandImage, 0, 0)
        $brand.Controls.Add($brandText, 1, 0)
    }
    else {
        $brand.ColumnCount = 1
        [void] $brand.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Percent, 100)))
        $brand.Controls.Add($brandText, 0, 0)
    }

    $providerLabel = New-KapselSectionLabel -Text 'Package provider'
    $providerPanel = New-Object System.Windows.Forms.FlowLayoutPanel
    $providerPanel.Dock = [System.Windows.Forms.DockStyle]::Fill
    $providerPanel.BackColor = $colors.Sidebar
    $providerPanel.WrapContents = $false

    $wingetButton = New-KapselProviderButton -Provider 'winget' -Available ([bool] $ProviderStatus.WingetAvailable)
    $chocoButton = New-KapselProviderButton -Provider 'choco' -Available ([bool] $ProviderStatus.ChocoAvailable)
    $providerPanel.Controls.AddRange(@($wingetButton, $chocoButton))

    $initialProvider = if ($ProviderStatus.WingetAvailable) { 'winget' } elseif ($ProviderStatus.ChocoAvailable) { 'choco' } else { $null }
    $providerState = [PSCustomObject] @{ Value = $initialProvider }
    $providerControlState = [PSCustomObject] @{
        ProviderState = $providerState
        Status        = $ProviderStatus
        WingetButton  = $wingetButton
        ChocoButton   = $chocoButton
    }
    $wingetButton.Name = 'winget'
    $chocoButton.Name = 'choco'
    $wingetButton.Tag = $providerControlState
    $chocoButton.Tag = $providerControlState
    $providerClick = {
        param($sender, $eventArgs)

        $state = $sender.Tag
        $provider = [string] $sender.Name
        $isWinget = $provider -eq 'winget' -and $state.Status.WingetAvailable
        $isChoco = $provider -eq 'choco' -and $state.Status.ChocoAvailable
        $state.ProviderState.Value = if ($isWinget) { 'winget' } elseif ($isChoco) { 'choco' } else { $null }
        Set-KapselProviderButtonState -Button $state.WingetButton -Active ($state.ProviderState.Value -eq 'winget') -Available ([bool] $state.Status.WingetAvailable)
        Set-KapselProviderButtonState -Button $state.ChocoButton -Active ($state.ProviderState.Value -eq 'choco') -Available ([bool] $state.Status.ChocoAvailable)
    }
    $wingetButton.Add_Click($providerClick)
    $chocoButton.Add_Click($providerClick)
    Set-KapselProviderButtonState -Button $wingetButton -Active ($initialProvider -eq 'winget') -Available ([bool] $ProviderStatus.WingetAvailable)
    Set-KapselProviderButtonState -Button $chocoButton -Active ($initialProvider -eq 'choco') -Available ([bool] $ProviderStatus.ChocoAvailable)

    $categoryLabel = New-KapselSectionLabel -Text 'Categories'
    $categoryTree = New-Object System.Windows.Forms.TreeView
    $categoryTree.Dock = [System.Windows.Forms.DockStyle]::Fill
    $categoryTree.BackColor = $colors.Sidebar
    $categoryTree.ForeColor = $colors.Text
    $categoryTree.BorderStyle = [System.Windows.Forms.BorderStyle]::None
    $categoryTree.Font = New-KapselFont -Size 8
    $categoryTree.HideSelection = $false
    $categoryTree.ShowLines = $false
    $categoryTree.ShowPlusMinus = $false
    $categoryTree.ShowRootLines = $false
    $categoryTree.ItemHeight = 29
    Set-KapselDarkTreeView -TreeView $categoryTree

    foreach ($category in @('All') + @($Categories | Where-Object { $_ -ne 'All' })) {
        $count = if ($category -eq 'All') { $Catalog.Count } else { @($Catalog | Where-Object { $_.Category -eq $category }).Count }
        $label = if ($category -eq 'All') { 'All applications' } else { $category }
        $node = New-Object System.Windows.Forms.TreeNode("{0}  {1}" -f $label, $count)
        $node.Tag = $category
        [void] $categoryTree.Nodes.Add($node)
        if ($category -eq $DefaultCategory) { $categoryTree.SelectedNode = $node }
    }
    if ($null -eq $categoryTree.SelectedNode -and $categoryTree.Nodes.Count -gt 0) {
        $categoryTree.SelectedNode = $categoryTree.Nodes[0]
    }

    $aboutLabel = New-KapselSectionLabel -Text 'About'
    $aboutPanel = New-Object System.Windows.Forms.Panel
    $aboutPanel.Dock = [System.Windows.Forms.DockStyle]::Fill
    $aboutPanel.BackColor = $colors.Sidebar
    $aboutLine = New-KapselLabel -Text "$($Metadata.Name) $($Metadata.Version)" -Size 7.5 -Color $colors.Text -Height 22
    $creatorLine = New-KapselLabel -Text "By $($Metadata.Creator)" -Size 7 -Color $colors.Muted -Height 20
    $catalogLine = New-KapselLabel -Text "$($Catalog.Count) curated applications" -Size 7 -Color $colors.Muted -Height 20
    $aboutPanel.Controls.AddRange(@($catalogLine, $creatorLine, $aboutLine))

    $sidebar.Controls.Add($brand, 0, 0)
    $sidebar.Controls.Add($providerLabel, 0, 1)
    $sidebar.Controls.Add($providerPanel, 0, 2)
    $sidebar.Controls.Add($categoryLabel, 0, 3)
    $sidebar.Controls.Add($categoryTree, 0, 4)
    $sidebar.Controls.Add($aboutLabel, 0, 5)
    $sidebar.Controls.Add($aboutPanel, 0, 6)

    return [PSCustomObject] @{
        Panel          = $sidebar
        ProviderState  = $providerState
        WingetButton   = $wingetButton
        ChocoButton    = $chocoButton
        CategoryTree   = $categoryTree
    }
}

Export-ModuleMember -Function 'New-KapselSidebarView'

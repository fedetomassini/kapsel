$ProjectRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
foreach ($module in @('CatalogView', 'ContextView', 'SidebarView', 'ShellView', 'WindowChrome', 'ApplicationGridView')) {
    Import-Module (Join-Path $ProjectRoot "src\modules\Presentation\WinForms\$module.psm1") -Force
}
Import-Module (Join-Path $ProjectRoot 'src\modules\Application\CatalogService.psm1') -Force
Import-Module (Join-Path $ProjectRoot 'src\modules\Infrastructure\JsonCatalogRepository.psm1') -Force
Import-Module (Join-Path $ProjectRoot 'src\modules\Shared\ProductMetadata.psm1') -Force

Describe 'Catalog grid interaction' {
    BeforeEach {
        $applications = @(for ($index = 0; $index -lt 30; $index++) {
            [PSCustomObject] @{ Key = "app-$index"; Name = ('App {0:d2}' -f $index); Category = 'Utilities'; Description = 'Full app description'; WingetId = "Publisher.App$index"; ChocoId = $null; Foss = $true; Link = 'https://example.com/' }
        })
        $form = New-Object System.Windows.Forms.Form
        $form.ClientSize = New-Object System.Drawing.Size(900, 300)
        $grid = New-KapselApplicationGrid
        $form.Controls.Add($grid)
        [void] $form.Handle
        [void] $grid.Handle
        Set-KapselApplicationGrid -Grid $grid -Applications $applications
    }
    AfterEach { $form.Dispose() }

    It 'preserves focused key, sort order and top visible key when rebinding reordered data' {
        $grid.Sort($grid.Columns['Name'], [ComponentModel.ListSortDirection]::Ascending)
        $grid.CurrentCell = $grid.Rows[8].Cells['Name']
        $grid.FirstDisplayedScrollingRowIndex = 6
        $topKey = [string] $grid.Rows[$grid.FirstDisplayedScrollingRowIndex].Cells['Key'].Value
        $reversed = @($applications)
        [array]::Reverse($reversed)
        Set-KapselApplicationGrid -Grid $grid -Applications $reversed -SelectedKeys @('APP-8')
        Get-KapselCurrentApplicationKey -Grid $grid | Should Be 'app-8'
        $grid.Rows[$grid.FirstDisplayedScrollingRowIndex].Cells['Key'].Value | Should Be $topKey
        $grid.SortOrder | Should Be ([System.Windows.Forms.SortOrder]::Ascending)
        $grid.CurrentRow.Cells['Selected'].Value | Should Be $true
        @((Get-KapselVisibleSelectionKeys -Grid $grid)).Count | Should Be 1
    }

    It 'suppresses per-row reconciliation during bulk changes but leaves individual edits observable' {
        $grid.CurrentCell = $grid.Rows[8].Cells['Name']
        $grid.FirstDisplayedScrollingRowIndex = 6
        $topKey = [string] $grid.Rows[$grid.FirstDisplayedScrollingRowIndex].Cells['Key'].Value
        $events = [PSCustomObject] @{ Reconciliations = 0 }
        $grid.Add_CellValueChanged({
            param($sender, $eventArgs)
            if (-not $sender.Tag.Updating -and $eventArgs.RowIndex -ge 0) { $events.Reconciliations++ }
        }.GetNewClosure())
        Set-KapselVisibleSelection -Grid $grid -Selected $true
        @(Get-KapselVisibleSelectionKeys -Grid $grid).Count | Should Be 30
        $events.Reconciliations | Should Be 0
        Get-KapselCurrentApplicationKey -Grid $grid | Should Be 'app-8'
        $grid.Rows[$grid.FirstDisplayedScrollingRowIndex].Cells['Key'].Value | Should Be $topKey
        Set-KapselVisibleSelection -Grid $grid -Selected $false
        @(Get-KapselVisibleSelectionKeys -Grid $grid).Count | Should Be 0
        $grid.Rows[0].Cells['Selected'].Value = $true
        $events.Reconciliations | Should Be 1
        $grid.Tag.Updating | Should Be $false
    }

    It 'clears stale focus when the view becomes empty and shows full description tooltips' {
        $grid.Rows[0].Cells['Description'].ToolTipText | Should Be 'Full app description'
        Set-KapselApplicationGrid -Grid $grid -Applications @()
        Get-KapselCurrentApplicationKey -Grid $grid | Should BeNullOrEmpty
        $grid.Rows.Count | Should Be 0
    }
}

Describe 'Focused application details' {
    It 'shows exact identifiers and version while distinguishing a failed update check' {
        $view = New-KapselContextView -Metadata (Get-KapselProductMetadata)
        try {
            $app = [PSCustomObject] @{ Key = 'firefox'; Name = 'Firefox'; Category = 'Browsers'; Description = 'A full description'; WingetId = 'Mozilla.Firefox'; ChocoId = $null; Foss = $true; Link = 'https://example.com/' }
            $state = [PSCustomObject] @{ Status = 'Installed'; Version = '130.0'; UpdateCheckSucceeded = $false }
            Set-KapselApplicationDetails -View $view -Application $app -Provider winget -InventoryState $state
            $view.DetailLabels.Name.Text | Should Be 'Firefox'
            $view.DetailLabels.Version.Text | Should Match '130.0'
            $view.DetailLabels.Winget.Text | Should Match 'Mozilla.Firefox'
            $view.DetailLabels.Choco.Text | Should Match 'Not supported'
            $view.DetailLabels.UpdateCheck.Text | Should Match 'unavailable'
            Set-KapselApplicationDetails -View $view -Application $null -Provider winget
            $view.DetailLabels.Name.Text | Should Be 'Choose an application'
            $view.DetailLabels.Description.Text | Should Match 'Focus a catalog row'
        }
        finally { $view.Panel.Dispose() }
    }
}

Describe 'Minimum-window layout' {
    It 'uses the fallback font without clipping the minimum-window actions' {
        $themes = @(Get-Module -All Theme)
        $families = @($themes | ForEach-Object { & $_ { $script:KapselFontFamily } })
        $form = New-Object System.Windows.Forms.Form
        try {
            foreach ($theme in $themes) { & $theme { $script:KapselFontFamily = 'Segoe UI' } }
            $snapshot = New-KapselCatalogSnapshot -CatalogDocument (Read-KapselApplicationCatalogDocument)
            $catalog = New-KapselCatalogView -Snapshot $snapshot
            $form.ClientSize = New-Object System.Drawing.Size(634, 620)
            $form.Controls.Add($catalog.Panel)
            [void] $form.Handle
            $form.PerformLayout()
            $catalog.SearchBox.Font.Name | Should Be 'Segoe UI'
            foreach ($button in @($catalog.SelectAllButton, $catalog.ClearButton, $catalog.FavoriteButton, $catalog.OpenLinkButton, $catalog.UpgradeButton, $catalog.InstallButton)) {
                ($button.Right -le $button.Parent.ClientSize.Width) | Should Be $true
            }
        }
        finally {
            $form.Dispose()
            for ($index = 0; $index -lt $themes.Count; $index++) { & $themes[$index] { param($family) $script:KapselFontFamily = $family } $families[$index] }
        }
    }

    It 'keeps primary actions inside their container at simulated display scale <Scale>' -TestCases @(
        @{ Scale = 1.0 }, @{ Scale = 1.25 }, @{ Scale = 1.5 }, @{ Scale = 2.0 }
    ) {
        param($Scale)
        $metadata = Get-KapselProductMetadata
        $form = New-KapselBorderlessForm -Metadata $metadata
        $snapshot = New-KapselCatalogSnapshot -CatalogDocument (Read-KapselApplicationCatalogDocument)
        $sidebar = New-KapselSidebarView -Metadata $metadata -Catalog $snapshot.Applications -Categories $snapshot.Categories -DefaultCategory All -ProviderStatus ([PSCustomObject] @{ WingetAvailable = $true; ChocoAvailable = $false })
        $catalog = New-KapselCatalogView -Snapshot $snapshot
        $context = New-KapselContextView -Metadata $metadata
        $shell = New-KapselShellView -Form $form -Sidebar $sidebar.Panel -Catalog $catalog.Panel -Context $context.Panel -Metadata $metadata
        $form.Controls.Add($shell.Panel)
        try {
            $form.Size = New-Object System.Drawing.Size(1180, 700)
            [void] $form.Handle
            $form.PerformLayout()
            if ($Scale -ne 1) {
                $form.Scale((New-Object System.Drawing.SizeF($Scale, $Scale)))
                $form.Size = New-Object System.Drawing.Size(([int] (1180 * $Scale)), ([int] (700 * $Scale)))
                $form.PerformLayout()
            }
            foreach ($button in @($catalog.SelectAllButton, $catalog.ClearButton, $catalog.FavoriteButton, $catalog.OpenLinkButton, $catalog.UpgradeButton, $catalog.InstallButton)) {
                ($button.Right -le $button.Parent.ClientSize.Width) | Should Be $true
                ($button.Bottom -le $button.Parent.ClientSize.Height) | Should Be $true
            }
            $catalog.SearchBox.AccessibleName | Should Be 'Search applications'
            $catalog.Grid.AccessibleName | Should Be 'Application catalog'
            $sidebar.CategoryTree.AccessibleName | Should Be 'Application categories'
        }
        finally { $form.Dispose() }
    }
}

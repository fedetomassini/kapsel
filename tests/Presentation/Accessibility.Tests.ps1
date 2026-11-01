$ProjectRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
foreach ($module in @('CatalogView', 'ContextView', 'SidebarView', 'ShellView', 'WindowChrome', 'ApplicationGridView')) {
    Import-Module (Join-Path $ProjectRoot "src\modules\Presentation\WinForms\$module.psm1") -Force
}
Import-Module (Join-Path $ProjectRoot 'src\modules\Application\CatalogService.psm1') -Force
Import-Module (Join-Path $ProjectRoot 'src\modules\Infrastructure\JsonCatalogRepository.psm1') -Force
Import-Module (Join-Path $ProjectRoot 'src\modules\Shared\ProductMetadata.psm1') -Force

function Get-KapselDescendantControl {
    param([Parameter(Mandatory = $true)] [System.Windows.Forms.Control] $Control)

    foreach ($child in $Control.Controls) {
        $child
        Get-KapselDescendantControl -Control $child
    }
}

Describe 'Accessibility' {
    It 'names every focusable control and keeps a logical action tab order' {
        $metadata = Get-KapselProductMetadata
        $form = New-KapselBorderlessForm -Metadata $metadata
        $snapshot = New-KapselCatalogSnapshot -CatalogDocument (Read-KapselApplicationCatalogDocument)
        $sidebar = New-KapselSidebarView -Metadata $metadata -Catalog $snapshot.Applications -Categories $snapshot.Categories -DefaultCategory All -ProviderStatus ([PSCustomObject] @{ WingetAvailable = $true; ChocoAvailable = $true })
        $catalog = New-KapselCatalogView -Snapshot $snapshot
        $context = New-KapselContextView -Metadata $metadata
        $shell = New-KapselShellView -Form $form -Sidebar $sidebar.Panel -Catalog $catalog.Panel -Context $context.Panel -Metadata $metadata
        $form.Controls.Add($shell.Panel)
        try {
            $form.MinimumSize = New-Object System.Drawing.Size(0, 0)
            $form.Size = New-Object System.Drawing.Size(1180, 700)
            [void] $form.Handle
            $form.PerformLayout()

            $all = @($shell.Panel) + @(Get-KapselDescendantControl -Control $shell.Panel)
            $focusable = @($all | Where-Object { $_.TabStop })
            ($focusable.Count -gt 0) | Should Be $true
            foreach ($control in $focusable) {
                if ([string]::IsNullOrWhiteSpace($control.AccessibleName)) {
                    throw "Focusable $($control.GetType().Name) '$($control.Name)' has no accessible name."
                }
            }

            $actions = @($catalog.SelectAllButton, $catalog.ClearButton, $catalog.FavoriteButton, $catalog.OpenLinkButton, $catalog.UpgradeButton, $catalog.InstallButton)
            (@($actions | ForEach-Object { $_.TabIndex }) -join ',') | Should Be '0,1,2,3,4,5'
            foreach ($button in $actions) {
                if ([string]::IsNullOrWhiteSpace($button.AccessibleDescription)) {
                    throw "Action '$($button.Text)' has no accessible description."
                }
            }

            (@($sidebar.WingetButton.TabIndex, $sidebar.ChocoButton.TabIndex) -join ',') | Should Be '0,1'
            $sidebar.WingetButton.AccessibleDescription | Should Not BeNullOrEmpty
            $catalog.SearchBox.AccessibleDescription | Should Not BeNullOrEmpty
            $shell.DiagnosticsButton.AccessibleDescription | Should Not BeNullOrEmpty
            $context.State.Buttons['Activity'].AccessibleDescription | Should Not BeNullOrEmpty
        }
        finally { $form.Dispose() }
    }
}

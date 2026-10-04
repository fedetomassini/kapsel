# Right-side contextual information and activity surface.
Set-StrictMode -Version Latest

Import-Module (Join-Path $PSScriptRoot 'Theme.psm1') -Force

Add-Type -AssemblyName System.Windows.Forms

function Get-KapselFeatureLines {
    [CmdletBinding()]
    param()

    return @(
        'CATALOG',
        'Curated Windows application catalog.',
        'Search by app, category, description, or package id.',
        'Focused category navigation and FOSS filtering.',
        'Installed-app and available-update filters.',
        'Persistent favorites stored per Windows user.',
        'Focused application details, installed versions and provider identifiers.',
        'Visible and hidden selection counts, with keyboard selection shortcuts.',
        '',
        'OPERATIONS',
        'Batch install and update workflows.',
        'Background execution with application progress and elapsed time.',
        'winget and Chocolatey provider support.',
        'Explicit confirmation before process execution.',
        'Unsupported packages are skipped and reported.',
        'Results and provider errors are explained directly in Activity.',
        '',
        'FOSS',
        'Free and Open Source Software has source code available under an open license.'
    )
}

function Get-KapselChangelogLines {
    [CmdletBinding()]
    param([Parameter(Mandatory = $true)] [object] $Metadata)

    return @(
        "VERSION $($Metadata.Version)",
        'Persistent favorites with a dedicated catalog view.',
        'Fixed install and update confirmation crashes.',
        'Responsive background operations with visible progress.',
        'Installed-app detection and update availability.',
        'No available updates are reported as unchanged, not failed.',
        'Provider error details and summaries appear in Activity.',
        'Readable wrapping text and preserved Activity reading position.',
        'Script-based release ZIP; executable builds are optional.'
    )
}

function Set-KapselContextSection {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)] [object] $State,
        [Parameter(Mandatory = $true)] [string] $Title
    )

    $colors = Get-KapselUiColors
    foreach ($key in $State.Buttons.Keys) {
        $active = $key -eq $Title
        $button = $State.Buttons[$key]
        $button.BackColor = if ($active) { $colors.SurfaceAlt } else { $colors.Window }
        $button.ForeColor = if ($active) { $colors.Text } else { $colors.Muted }
        $button.FlatAppearance.BorderColor = if ($active) { $colors.Accent } else { $colors.Border }
        $State.Panels[$key].Visible = $active
        if ($active) { $State.Panels[$key].BringToFront() }
    }
    $State.Active = $Title
}

function New-KapselContextButton {
    [CmdletBinding()]
    param([Parameter(Mandatory = $true)] [string] $Title)

    $button = New-KapselButton -Text $Title -Icon $Title
    $button.Name = "KapselContext$($Title)Button"
    $button.AccessibleName = $Title
    $button.Dock = [System.Windows.Forms.DockStyle]::Fill
    $button.Margin = New-Object System.Windows.Forms.Padding(2, 3, 2, 3)
    $button.Height = 30
    return $button
}

function New-KapselContextView {
    [CmdletBinding()]
    param([Parameter(Mandatory = $true)] [object] $Metadata)

    $colors = Get-KapselUiColors
    $view = New-Object System.Windows.Forms.TableLayoutPanel
    $view.Dock = [System.Windows.Forms.DockStyle]::Fill
    $view.Margin = New-Object System.Windows.Forms.Padding(0)
    $view.Padding = New-Object System.Windows.Forms.Padding(0)
    $view.BackColor = $colors.Context
    $view.ColumnCount = 1
    $view.RowCount = 2
    [void] $view.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 76)))
    [void] $view.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Percent, 100)))

    $navigation = New-Object System.Windows.Forms.TableLayoutPanel
    $navigation.Dock = [System.Windows.Forms.DockStyle]::Fill
    $navigation.Margin = New-Object System.Windows.Forms.Padding(0)
    $navigation.Padding = New-Object System.Windows.Forms.Padding(4, 0, 4, 0)
    $navigation.BackColor = $colors.Window
    $navigation.ColumnCount = 2
    $navigation.RowCount = 2
    $navigation.TabIndex = 0
    foreach ($index in 1..2) {
        [void] $navigation.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Percent, 50)))
        [void] $navigation.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Percent, 50)))
    }

    $contentHost = New-Object System.Windows.Forms.Panel
    $contentHost.Dock = [System.Windows.Forms.DockStyle]::Fill
    $contentHost.Margin = New-Object System.Windows.Forms.Padding(0)
    $contentHost.Padding = New-Object System.Windows.Forms.Padding(0)
    $contentHost.BackColor = $colors.Context

    $activityPanel = New-KapselVisualList
    $featurePanel = New-KapselVisualList -Lines (Get-KapselFeatureLines)
    $changelogPanel = New-KapselVisualList -Lines (Get-KapselChangelogLines -Metadata $Metadata)
    $detailsPanel = New-KapselVisualList
    $detailLabels = @{}
    foreach ($field in @('Name', 'Category', 'Description', 'Inventory', 'Version', 'UpdateCheck', 'Winget', 'Choco', 'Website')) {
        $label = Add-KapselVisualLine -Panel $detailsPanel -Text ' '
        $label.Name = "KapselDetails$field"
        if ($field -eq 'Name') {
            $label.Font.Dispose()
            $label.Font = New-KapselFont -Size 12 -Style ([System.Drawing.FontStyle]::Bold)
            $label.ForeColor = $colors.Text
        }
        $detailLabels[$field] = $label
    }
    $buttons = @{}
    $panels = @{
        Details  = $detailsPanel
        Activity = $activityPanel
        Features = $featurePanel
        Changes  = $changelogPanel
    }
    $column = 0
    foreach ($title in @('Details', 'Activity', 'Features', 'Changes')) {
        $button = New-KapselContextButton -Title $title
        $buttons[$title] = $button
        $button.TabIndex = $column
        $navigation.Controls.Add($button, ($column % 2), ([int] [Math]::Floor($column / 2)))
        $contentHost.Controls.Add($panels[$title])
        $column++
    }

    $state = [PSCustomObject] @{
        Buttons = $buttons
        Panels  = $panels
        Active  = $null
    }
    foreach ($button in $buttons.Values) {
        $button.Tag = $state
        $button.Add_Click({
            param($sender, $eventArgs)

            $title = $sender.Text
            Set-KapselContextSection -State $sender.Tag -Title $title
        })
    }
    Set-KapselContextSection -State $state -Title 'Details'
    $view.Controls.Add($navigation, 0, 0)
    $view.Controls.Add($contentHost, 0, 1)

    return [PSCustomObject] @{
        Panel         = $view
        ActivityPanel = $activityPanel
        State         = $state
        DetailLabels  = $detailLabels
        DetailIdentity = ''
    }
}

function Set-KapselApplicationDetails {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)] [object] $View,
        [AllowNull()] [object] $Application,
        [AllowNull()] [string] $Provider,
        [AllowNull()] [object] $InventoryState,
        [AllowNull()] [object] $ProviderDiagnostics
    )

    $key = if ($null -ne $Application) { [string] $Application.Key } else { '' }
    $status = if ($null -ne $InventoryState) { [string] $InventoryState.Status } else { '' }
    $version = if ($null -ne $InventoryState) { [string] $InventoryState.Version } else { '' }
    $checked = $null -ne $InventoryState -and $InventoryState.UpdateCheckSucceeded
    $providerVersion = if ($null -ne $ProviderDiagnostics) { [string] $ProviderDiagnostics.Version } else { '' }
    $identity = "$key|$Provider|$status|$version|$checked|$providerVersion"
    if ($View.DetailIdentity -eq $identity) { return }
    $View.DetailIdentity = $identity
    $labels = $View.DetailLabels
    $panel = $View.State.Panels['Details']
    $panel.SuspendLayout()
    try {
        foreach ($label in $labels.Values) { $label.Visible = $null -ne $Application }
        $labels.Name.Visible = $true
        $labels.Name.Text = if ($null -eq $Application) { 'Choose an application' } else { $Application.Name }
        $labels.Description.Visible = $true
        if ($null -eq $Application) {
            $labels.Description.Text = 'Focus a catalog row to see its description, provider identifiers and installed version.'
            return
        }
        $labels.Category.Text = "$($Application.Category) | FOSS: $(if ($Application.Foss) { 'Yes' } else { 'No' })"
        $labels.Description.Text = if ([string]::IsNullOrWhiteSpace($Application.Description)) { 'No description available.' } else { $Application.Description }
        $statusText = switch ($status) {
            'Installed' { 'Installed' }
            'UpdateAvailable' { 'Update available' }
            'NotDetected' { 'Not detected by this provider' }
            'Unsupported' { 'Unavailable through this provider' }
            default { 'Inventory not checked' }
        }
        $providerText = if ([string]::IsNullOrWhiteSpace($Provider)) { 'No provider available' } else { "$Provider $providerVersion".Trim() }
        $labels.Inventory.Text = "${providerText}: $statusText"
        $colors = Get-KapselUiColors
        $labels.Inventory.ForeColor = if ($status -eq 'UpdateAvailable') { $colors.Warning } elseif ($status -eq 'Installed') { $colors.Success } else { $colors.Muted }
        $labels.Version.Text = if ($version) { "Installed version: $version" } else { 'Installed version: unknown' }
        $labels.UpdateCheck.Text = if ($null -eq $InventoryState) { 'Update check: not available yet' } elseif ($checked) { 'Update check: completed' } else { 'Update check: unavailable' }
        $labels.Winget.Text = "winget: $(if ($Application.WingetId) { $Application.WingetId } else { 'Not supported' })"
        $labels.Choco.Text = "Chocolatey: $(if ($Application.ChocoId) { $Application.ChocoId } else { 'Not supported' })"
        $labels.Website.Text = if ($Application.Link) { "Official website: $($Application.Link)" } else { 'Official website: not provided' }
    }
    finally {
        $panel.ResumeLayout($true)
    }
}

Export-ModuleMember -Function @(
    'New-KapselContextView',
    'Get-KapselFeatureLines',
    'Get-KapselChangelogLines',
    'Set-KapselContextSection',
    'Set-KapselApplicationDetails'
)

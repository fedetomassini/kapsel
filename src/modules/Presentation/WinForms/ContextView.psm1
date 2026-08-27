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
        '',
        'OPERATIONS',
        'Batch install and update workflows.',
        'winget and Chocolatey provider support.',
        'Explicit confirmation before process execution.',
        'Unsupported packages are skipped and reported.',
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
        'Layered architecture with explicit domain boundaries.',
        'Compact three-pane desktop workspace.',
        'Package providers isolated behind an adapter.',
        'Catalog validation and selection persistence.',
        'Expanded architecture and contributor documentation.'
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

    $button = New-KapselButton -Text $Title
    $button.Name = "KapselContext$($Title)Button"
    $button.AccessibleName = "$Title section"
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
    [void] $view.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 38)))
    [void] $view.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Percent, 100)))

    $navigation = New-Object System.Windows.Forms.TableLayoutPanel
    $navigation.Dock = [System.Windows.Forms.DockStyle]::Fill
    $navigation.Margin = New-Object System.Windows.Forms.Padding(0)
    $navigation.Padding = New-Object System.Windows.Forms.Padding(4, 0, 4, 0)
    $navigation.BackColor = $colors.Window
    $navigation.ColumnCount = 3
    $navigation.RowCount = 1
    foreach ($index in 1..3) {
        [void] $navigation.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Percent, 33.333)))
    }

    $contentHost = New-Object System.Windows.Forms.Panel
    $contentHost.Dock = [System.Windows.Forms.DockStyle]::Fill
    $contentHost.Margin = New-Object System.Windows.Forms.Padding(0)
    $contentHost.Padding = New-Object System.Windows.Forms.Padding(0)
    $contentHost.BackColor = $colors.Context

    $activityPanel = New-KapselVisualList
    $featurePanel = New-KapselVisualList -Lines (Get-KapselFeatureLines)
    $changelogPanel = New-KapselVisualList -Lines (Get-KapselChangelogLines -Metadata $Metadata)
    $buttons = @{}
    $panels = @{
        Activity = $activityPanel
        Features = $featurePanel
        Changes  = $changelogPanel
    }
    $column = 0
    foreach ($title in @('Activity', 'Features', 'Changes')) {
        $button = New-KapselContextButton -Title $title
        $buttons[$title] = $button
        $navigation.Controls.Add($button, $column, 0)
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
    Set-KapselContextSection -State $state -Title 'Activity'
    $view.Controls.Add($navigation, 0, 0)
    $view.Controls.Add($contentHost, 0, 1)

    return [PSCustomObject] @{
        Panel         = $view
        ActivityPanel = $activityPanel
    }
}

Export-ModuleMember -Function @(
    'New-KapselContextView',
    'Get-KapselFeatureLines',
    'Get-KapselChangelogLines',
    'Set-KapselContextSection'
)

# Bottom information section: activity log, features, and changelog.
Set-StrictMode -Version Latest

Import-Module (Join-Path $PSScriptRoot 'UiTheme.psm1') -Force

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

function Get-KapselFeatureLines {
    [CmdletBinding()]
    param()

    return @(
        'Features',
        '',
        'Curated catalog from src/applications.json.',
        'Category navigation with focused application discovery.',
        'Search by name, key, description, winget id, or Chocolatey id.',
        'FOSS-only filtering for open-source software.',
        'Batch install and update through winget or Chocolatey.',
        'Explicit confirmation before package operations.',
        'Package manager availability shown inside the UI.',
        'Official website shortcut for the selected application.'
    )
}

function Get-KapselChangelogLines {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [object] $Metadata
    )

    return @(
        'Changelog',
        '',
        "Version $($Metadata.Version)",
        'Modernized the main application layout.',
        'Added logo support through src/images.',
        'Replaced visual text fields with non-selectable labels.',
        'Improved activity, features, and changelog sections.',
        'Refined grid density, action controls, and package workflow feedback.'
    )
}

function New-KapselInfoPage {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string] $Title,

        [Parameter(Mandatory = $true)]
        [System.Windows.Forms.Control] $Content
    )

    $colors = Get-KapselUiColors
    $page = New-Object System.Windows.Forms.TabPage
    $page.Text = $Title
    $page.BackColor = $colors.Window
    $page.Padding = New-Object System.Windows.Forms.Padding(0)
    $page.Controls.Add($Content)
    return $page
}

function New-KapselInfoSection {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [object] $Metadata
    )

    $colors = Get-KapselUiColors
    $tabs = New-Object System.Windows.Forms.TabControl
    $tabs.Dock = [System.Windows.Forms.DockStyle]::Fill
    $tabs.Font = New-KapselFont -Size 8.5
    $tabs.Appearance = [System.Windows.Forms.TabAppearance]::FlatButtons
    $tabs.ItemSize = New-Object System.Drawing.Size(104, 28)
    $tabs.SizeMode = [System.Windows.Forms.TabSizeMode]::Fixed

    $activityLog = New-KapselVisualTextPanel
    $featuresPanel = New-KapselVisualTextPanel -Lines (Get-KapselFeatureLines)
    $changelogPanel = New-KapselVisualTextPanel -Lines (Get-KapselChangelogLines -Metadata $Metadata)

    $tabs.TabPages.AddRange(@(
        (New-KapselInfoPage -Title 'Activity' -Content $activityLog),
        (New-KapselInfoPage -Title 'Features' -Content $featuresPanel),
        (New-KapselInfoPage -Title 'Changelog' -Content $changelogPanel)
    ))

    return [PSCustomObject] @{
        Panel  = $tabs
        LogBox = $activityLog
    }
}

Export-ModuleMember -Function @(
    'New-KapselInfoSection',
    'Get-KapselFeatureLines',
    'Get-KapselChangelogLines'
)

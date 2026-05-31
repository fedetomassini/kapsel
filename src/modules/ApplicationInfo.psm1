# Bottom information section: activity log, features, and changelog.
Set-StrictMode -Version Latest

Import-Module (Join-Path $PSScriptRoot 'UiTheme.psm1') -Force

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

function New-KapselReadOnlyTextBox {
    [CmdletBinding()]
    param(
        [string] $Text = ''
    )

    $colors = Get-KapselUiColors
    $textBox = New-Object System.Windows.Forms.TextBox
    $textBox.Dock = [System.Windows.Forms.DockStyle]::Fill
    $textBox.Multiline = $true
    $textBox.ReadOnly = $true
    $textBox.ScrollBars = [System.Windows.Forms.ScrollBars]::Vertical
    $textBox.BorderStyle = [System.Windows.Forms.BorderStyle]::FixedSingle
    $textBox.BackColor = $colors.Surface
    $textBox.ForeColor = $colors.Text
    $textBox.Font = New-KapselFont -Size 8.5
    $textBox.Text = $Text
    return $textBox
}

function Get-KapselFeatureText {
    [CmdletBinding()]
    param()

    return @(
        'Features',
        '',
        '- Curated local application catalog from src/applications.json.',
        '- Category navigation for focused application discovery.',
        '- Search by name, key, description, winget id, or Chocolatey id.',
        '- Optional FOSS-only filter for open-source software.',
        '- Batch install and update through winget or Chocolatey.',
        '- Explicit confirmation before package operations.',
        '- Package manager availability shown inside the UI.',
        '- Official website shortcut for the selected application.'
    ) -join [Environment]::NewLine
}

function Get-KapselChangelogText {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [object] $Metadata
    )

    return @(
        'Changelog',
        '',
        "Version $($Metadata.Version)",
        '- Renamed the project to Kapsel.',
        '- Reworked the app around application install and update workflows.',
        '- Split the Windows Forms UI into focused modules.',
        '- Added Features and Changelog sections to the interface.',
        '- Improved filter, action, and activity areas for better scanning.'
    ) -join [Environment]::NewLine
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
    $tabs.Appearance = [System.Windows.Forms.TabAppearance]::Normal

    $activityPage = New-Object System.Windows.Forms.TabPage
    $activityPage.Text = 'Activity'
    $activityPage.BackColor = $colors.Window
    $activityLog = New-KapselReadOnlyTextBox
    $activityPage.Controls.Add($activityLog)

    $featuresPage = New-Object System.Windows.Forms.TabPage
    $featuresPage.Text = 'Features'
    $featuresPage.BackColor = $colors.Window
    $featuresPage.Controls.Add((New-KapselReadOnlyTextBox -Text (Get-KapselFeatureText)))

    $changelogPage = New-Object System.Windows.Forms.TabPage
    $changelogPage.Text = 'Changelog'
    $changelogPage.BackColor = $colors.Window
    $changelogPage.Controls.Add((New-KapselReadOnlyTextBox -Text (Get-KapselChangelogText -Metadata $Metadata)))

    $tabs.TabPages.AddRange(@($activityPage, $featuresPage, $changelogPage))

    return [PSCustomObject] @{
        Panel  = $tabs
        LogBox = $activityLog
    }
}

Export-ModuleMember -Function @(
    'New-KapselInfoSection',
    'Get-KapselFeatureText',
    'Get-KapselChangelogText'
)

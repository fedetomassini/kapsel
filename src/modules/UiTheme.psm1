# Shared Windows Forms styling primitives for Kapsel.
Set-StrictMode -Version Latest

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# Kapsel's UI theme is defined here, with colors, fonts, and common controls.
$script:KapselFontFamily = $null

function Get-KapselUiColors {
    [CmdletBinding()]
    param()

    return @{
        Window     = [System.Drawing.Color]::FromArgb(24, 26, 30)
        Sidebar    = [System.Drawing.Color]::FromArgb(29, 32, 37)
        Surface    = [System.Drawing.Color]::FromArgb(34, 37, 43)
        SurfaceAlt = [System.Drawing.Color]::FromArgb(43, 47, 54)
        Border     = [System.Drawing.Color]::FromArgb(70, 76, 86)
        Text       = [System.Drawing.Color]::FromArgb(236, 239, 244)
        Muted      = [System.Drawing.Color]::FromArgb(165, 173, 184)
        Accent     = [System.Drawing.Color]::FromArgb(67, 185, 136)
        AccentDark = [System.Drawing.Color]::FromArgb(38, 120, 88)
        Warning    = [System.Drawing.Color]::FromArgb(229, 160, 82)
        Danger     = [System.Drawing.Color]::FromArgb(217, 83, 79)
        Status     = [System.Drawing.Color]::FromArgb(20, 22, 26)
    }
}

function Get-KapselUiFontFamily {
    [CmdletBinding()]
    param()

    $families = [System.Drawing.FontFamily]::Families | Select-Object -ExpandProperty Name
    if ($families -contains 'JetBrains Mono') { return 'JetBrains Mono' }
    if ($families -contains 'JetBrains Mono NL') { return 'JetBrains Mono NL' }
    return 'Segoe UI'
}

function Initialize-KapselUiTheme {
    [CmdletBinding()]
    param()

    $script:KapselFontFamily = Get-KapselUiFontFamily
}

function New-KapselFont {
    [CmdletBinding()]
    param(
        [float] $Size = 10,
        [System.Drawing.FontStyle] $Style = [System.Drawing.FontStyle]::Regular
    )

    if ([string]::IsNullOrWhiteSpace($script:KapselFontFamily)) {
        Initialize-KapselUiTheme
    }

    return New-Object System.Drawing.Font($script:KapselFontFamily, $Size, $Style)
}

function New-KapselButton {
    [CmdletBinding()]
    param(
        [string] $Text,
        [System.Drawing.Color] $BackColor = (Get-KapselUiColors).SurfaceAlt
    )

    $colors = Get-KapselUiColors
    $button = New-Object System.Windows.Forms.Button
    $button.Text = $Text
    $button.Width = 154
    $button.Height = 36
    $button.Margin = New-Object System.Windows.Forms.Padding(0, 0, 10, 0)
    $button.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $button.FlatAppearance.BorderColor = $colors.Border
    $button.FlatAppearance.MouseOverBackColor = $colors.Surface
    $button.FlatAppearance.MouseDownBackColor = $colors.AccentDark
    $button.BackColor = $BackColor
    $button.ForeColor = $colors.Text
    $button.Font = New-KapselFont -Size 9
    return $button
}

function New-KapselSectionLabel {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string] $Text
    )

    $colors = Get-KapselUiColors
    $label = New-Object System.Windows.Forms.Label
    $label.Text = $Text
    $label.Dock = [System.Windows.Forms.DockStyle]::Top
    $label.Height = 18
    $label.ForeColor = $colors.Muted
    $label.Font = New-KapselFont -Size 8
    return $label
}

function New-KapselStat {
    [CmdletBinding()]
    param(
        [string] $Title,
        [string] $Value
    )

    $colors = Get-KapselUiColors
    $panel = New-Object System.Windows.Forms.Panel
    $panel.Width = 178
    $panel.Height = 66
    $panel.Margin = New-Object System.Windows.Forms.Padding(0, 0, 12, 0)
    $panel.BackColor = $colors.SurfaceAlt

    $titleLabel = New-Object System.Windows.Forms.Label
    $titleLabel.Text = $Title
    $titleLabel.Left = 12
    $titleLabel.Top = 8
    $titleLabel.Width = 154
    $titleLabel.Height = 18
    $titleLabel.Font = New-KapselFont -Size 8
    $titleLabel.ForeColor = $colors.Muted

    $valueLabel = New-Object System.Windows.Forms.Label
    $valueLabel.Text = $Value
    $valueLabel.Left = 12
    $valueLabel.Top = 28
    $valueLabel.Width = 154
    $valueLabel.Height = 26
    $valueLabel.Font = New-KapselFont -Size 13 -Style ([System.Drawing.FontStyle]::Bold)
    $valueLabel.ForeColor = $colors.Text

    $panel.Controls.AddRange(@($titleLabel, $valueLabel))
    return $panel
}

function Write-KapselLog {
    [CmdletBinding()]
    param(
        [System.Windows.Forms.TextBox] $LogBox,
        [string] $Message
    )

    $timestamp = Get-Date -Format 'HH:mm:ss'
    $line = "[{0}] {1}{2}" -f $timestamp, $Message, [Environment]::NewLine
    $LogBox.AppendText($line)
}

Export-ModuleMember -Function @(
    'Get-KapselUiColors',
    'Get-KapselUiFontFamily',
    'Initialize-KapselUiTheme',
    'New-KapselFont',
    'New-KapselButton',
    'New-KapselSectionLabel',
    'New-KapselStat',
    'Write-KapselLog'
)

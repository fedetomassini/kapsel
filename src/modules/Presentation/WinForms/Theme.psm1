# Shared WinForms visual primitives. Product and package behavior do not belong here.
Set-StrictMode -Version Latest

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$script:KapselFontFamily = $null

function Get-KapselUiColors {
    [CmdletBinding()]
    param()

    return @{
        Window      = [System.Drawing.Color]::FromArgb(16, 16, 18)
        Sidebar     = [System.Drawing.Color]::FromArgb(21, 21, 24)
        Main        = [System.Drawing.Color]::FromArgb(25, 25, 28)
        Context     = [System.Drawing.Color]::FromArgb(20, 20, 23)
        Surface     = [System.Drawing.Color]::FromArgb(31, 31, 35)
        SurfaceAlt  = [System.Drawing.Color]::FromArgb(39, 39, 44)
        SurfaceSoft = [System.Drawing.Color]::FromArgb(48, 48, 54)
        Border      = [System.Drawing.Color]::FromArgb(55, 55, 62)
        Text        = [System.Drawing.Color]::FromArgb(238, 238, 242)
        Muted       = [System.Drawing.Color]::FromArgb(158, 158, 168)
        Subtle      = [System.Drawing.Color]::FromArgb(103, 103, 114)
        Accent      = [System.Drawing.Color]::FromArgb(126, 170, 238)
        AccentDark  = [System.Drawing.Color]::FromArgb(34, 48, 70)
        Success     = [System.Drawing.Color]::FromArgb(126, 204, 146)
        Warning     = [System.Drawing.Color]::FromArgb(224, 170, 92)
        Danger      = [System.Drawing.Color]::FromArgb(218, 104, 116)
        Info        = [System.Drawing.Color]::FromArgb(112, 181, 205)
        Selection   = [System.Drawing.Color]::FromArgb(36, 42, 52)
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
        [float] $Size = 9,
        [System.Drawing.FontStyle] $Style = [System.Drawing.FontStyle]::Regular
    )

    if ([string]::IsNullOrWhiteSpace($script:KapselFontFamily)) {
        Initialize-KapselUiTheme
    }
    return New-Object System.Drawing.Font($script:KapselFontFamily, $Size, $Style)
}

function New-KapselLabel {
    [CmdletBinding()]
    param(
        [AllowEmptyString()] [string] $Text = '',
        [float] $Size = 9,
        [System.Drawing.Color] $Color = (Get-KapselUiColors).Text,
        [System.Drawing.FontStyle] $Style = [System.Drawing.FontStyle]::Regular,
        [int] $Height = 22,
        [System.Windows.Forms.DockStyle] $Dock = [System.Windows.Forms.DockStyle]::Top,
        [System.Drawing.ContentAlignment] $TextAlign = [System.Drawing.ContentAlignment]::MiddleLeft
    )

    $label = New-Object System.Windows.Forms.Label
    $label.Text = $Text
    $label.Dock = $Dock
    $label.Height = $Height
    $label.ForeColor = $Color
    $label.Font = New-KapselFont -Size $Size -Style $Style
    $label.TextAlign = $TextAlign
    $label.AutoEllipsis = $true
    $label.TabStop = $false
    return $label
}

function New-KapselSectionLabel {
    [CmdletBinding()]
    param([Parameter(Mandatory = $true)] [string] $Text)

    $colors = Get-KapselUiColors
    $label = New-KapselLabel -Text $Text.ToUpperInvariant() -Size 7.5 -Color $colors.Subtle -Height 24
    $label.Padding = New-Object System.Windows.Forms.Padding(2, 0, 0, 0)
    return $label
}

function New-KapselButton {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)] [string] $Text,
        [int] $Width = 120,
        [System.Drawing.Color] $BackColor = (Get-KapselUiColors).Surface,
        [System.Drawing.Color] $ForeColor = (Get-KapselUiColors).Text,
        [System.Drawing.Color] $BorderColor = (Get-KapselUiColors).Border
    )

    $colors = Get-KapselUiColors
    $button = New-Object System.Windows.Forms.Button
    $button.Text = $Text
    $button.Width = $Width
    $button.Height = 32
    $button.Margin = New-Object System.Windows.Forms.Padding(0, 0, 8, 0)
    $button.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $button.FlatAppearance.BorderSize = 1
    $button.FlatAppearance.BorderColor = $BorderColor
    $button.FlatAppearance.MouseOverBackColor = $colors.SurfaceAlt
    $button.FlatAppearance.MouseDownBackColor = $colors.AccentDark
    $button.BackColor = $BackColor
    $button.ForeColor = $ForeColor
    $button.Font = New-KapselFont -Size 8
    $button.UseVisualStyleBackColor = $false
    return $button
}

function New-KapselMetric {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)] [string] $Label,
        [Parameter(Mandatory = $true)] [string] $Value,
        [System.Drawing.Color] $ValueColor = (Get-KapselUiColors).Text
    )

    $colors = Get-KapselUiColors
    $panel = New-Object System.Windows.Forms.Panel
    $panel.Width = 132
    $panel.Height = 42
    $panel.Margin = New-Object System.Windows.Forms.Padding(0, 0, 8, 0)
    $panel.BackColor = $colors.Surface

    $valueLabel = New-KapselLabel -Text $Value -Size 10 -Color $ValueColor -Style ([System.Drawing.FontStyle]::Bold) -Height 22
    $valueLabel.Padding = New-Object System.Windows.Forms.Padding(9, 2, 0, 0)
    $nameLabel = New-KapselLabel -Text $Label -Size 7 -Color $colors.Muted -Height 18
    $nameLabel.Padding = New-Object System.Windows.Forms.Padding(9, 0, 0, 0)
    $panel.Controls.AddRange(@($nameLabel, $valueLabel))
    return $panel
}

function New-KapselBrandImageView {
    [CmdletBinding()]
    param(
        [AllowNull()] [string] $ImagePath,
        [int] $Size = 38
    )

    if ([string]::IsNullOrWhiteSpace($ImagePath) -or -not (Test-Path -LiteralPath $ImagePath -PathType Leaf)) {
        return $null
    }

    $picture = New-Object System.Windows.Forms.PictureBox
    $picture.Width = $Size
    $picture.Height = $Size
    $picture.SizeMode = [System.Windows.Forms.PictureBoxSizeMode]::Zoom
    $picture.Image = New-Object System.Drawing.Bitmap($ImagePath)
    $picture.Add_Disposed({
        param($sender, $eventArgs)

        if ($null -ne $sender.Image) {
            $sender.Image.Dispose()
        }
    })
    return $picture
}

function New-KapselVisualList {
    [CmdletBinding()]
    param([string[]] $Lines = @())

    $colors = Get-KapselUiColors
    $panel = New-Object System.Windows.Forms.FlowLayoutPanel
    $panel.Dock = [System.Windows.Forms.DockStyle]::Fill
    $panel.FlowDirection = [System.Windows.Forms.FlowDirection]::TopDown
    $panel.WrapContents = $false
    $panel.AutoScroll = $true
    $panel.BackColor = $colors.Context
    $panel.Padding = New-Object System.Windows.Forms.Padding(14, 12, 14, 12)
    $panel.Add_Resize({
        param($sender, $eventArgs)

        foreach ($control in $sender.Controls) {
            $control.Width = [Math]::Max(120, [int] $sender.ClientSize.Width - 34)
        }
    })

    foreach ($line in $Lines) {
        Add-KapselVisualLine -Panel $panel -Text $line | Out-Null
    }
    return $panel
}

function Add-KapselVisualLine {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)] [System.Windows.Forms.Control] $Panel,
        [AllowEmptyString()] [string] $Text,
        [System.Drawing.Color] $Color = (Get-KapselUiColors).Muted,
        [float] $Size = 8,
        [System.Drawing.FontStyle] $Style = [System.Drawing.FontStyle]::Regular
    )

    $displayText = if ([string]::IsNullOrEmpty($Text)) { ' ' } else { $Text }
    $label = New-KapselLabel -Text $displayText -Size $Size -Color $Color -Style $Style -Height 23 -Dock ([System.Windows.Forms.DockStyle]::None)
    $label.Width = [Math]::Max(120, [int] $Panel.ClientSize.Width - 34)
    $label.Margin = New-Object System.Windows.Forms.Padding(0, 0, 0, 3)
    $Panel.Controls.Add($label)
    $Panel.ScrollControlIntoView($label)
    return $label
}

function Write-KapselActivity {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)] [System.Windows.Forms.Control] $ActivityPanel,
        [Parameter(Mandatory = $true)] [string] $Message,
        [ValidateSet('Info', 'Success', 'Warning', 'Error')]
        [string] $Level = 'Info'
    )

    $colors = Get-KapselUiColors
    $color = switch ($Level) {
        'Success' { $colors.Success }
        'Warning' { $colors.Warning }
        'Error' { $colors.Danger }
        default { $colors.Muted }
    }
    $timestamp = Get-Date -Format 'HH:mm:ss'
    Add-KapselVisualLine -Panel $ActivityPanel -Text ("[{0}] {1}" -f $timestamp, $Message) -Color $color | Out-Null
}

function Set-KapselTextBoxCueBanner {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)] [System.Windows.Forms.TextBox] $TextBox,
        [Parameter(Mandatory = $true)] [string] $Text
    )

    if (-not ('Kapsel.NativeMethods' -as [type])) {
        Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
namespace Kapsel {
    public static class NativeMethods {
        [DllImport("user32.dll", CharSet = CharSet.Unicode)]
        public static extern IntPtr SendMessage(IntPtr hWnd, int msg, IntPtr wParam, string lParam);
    }
}
"@
    }

    [Kapsel.NativeMethods]::SendMessage($TextBox.Handle, 0x1501, [IntPtr]::Zero, $Text) | Out-Null
}

function Set-KapselDarkTreeView {
    [CmdletBinding()]
    param([Parameter(Mandatory = $true)] [System.Windows.Forms.TreeView] $TreeView)

    $TreeView.DrawMode = [System.Windows.Forms.TreeViewDrawMode]::OwnerDrawText
    $TreeView.Add_DrawNode({
        param($sender, $eventArgs)

        $colors = Get-KapselUiColors
        $isSelected = ($eventArgs.State -band [System.Windows.Forms.TreeNodeStates]::Selected) -eq [System.Windows.Forms.TreeNodeStates]::Selected
        $clientWidth = [int] $sender.ClientSize.Width
        $itemHeight = [int] $sender.ItemHeight
        $nodeTop = [int] $eventArgs.Bounds.Top
        $bounds = New-Object System.Drawing.Rectangle(0, $nodeTop, $clientWidth, $itemHeight)
        $backColor = if ($isSelected) { $colors.Selection } else { $colors.Sidebar }
        $foreColor = if ($isSelected) { $colors.Text } else { $colors.Muted }
        $backBrush = New-Object System.Drawing.SolidBrush($backColor)
        $eventArgs.Graphics.FillRectangle($backBrush, $bounds)
        $backBrush.Dispose()

        $textBounds = New-Object System.Drawing.Rectangle(12, $nodeTop, [Math]::Max(24, $clientWidth - 18), $itemHeight)
        $flags = [System.Windows.Forms.TextFormatFlags]::VerticalCenter -bor
            [System.Windows.Forms.TextFormatFlags]::EndEllipsis -bor
            [System.Windows.Forms.TextFormatFlags]::NoPrefix
        [System.Windows.Forms.TextRenderer]::DrawText($eventArgs.Graphics, [string] $eventArgs.Node.Text, $sender.Font, $textBounds, $foreColor, $flags)
    })
}

Export-ModuleMember -Function @(
    'Get-KapselUiColors',
    'Get-KapselUiFontFamily',
    'Initialize-KapselUiTheme',
    'New-KapselFont',
    'New-KapselLabel',
    'New-KapselSectionLabel',
    'New-KapselButton',
    'New-KapselMetric',
    'New-KapselBrandImageView',
    'New-KapselVisualList',
    'Add-KapselVisualLine',
    'Write-KapselActivity',
    'Set-KapselTextBoxCueBanner',
    'Set-KapselDarkTreeView'
)

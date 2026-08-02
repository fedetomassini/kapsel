# Shared Windows Forms styling primitives for Kapsel.
Set-StrictMode -Version Latest

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$script:KapselFontFamily = $null

function Get-KapselUiColors {
    [CmdletBinding()]
    param()

    return @{
        Window       = [System.Drawing.Color]::FromArgb(16, 18, 22)
        Sidebar      = [System.Drawing.Color]::FromArgb(20, 23, 28)
        Surface      = [System.Drawing.Color]::FromArgb(27, 31, 38)
        SurfaceAlt   = [System.Drawing.Color]::FromArgb(35, 40, 48)
        SurfaceSoft  = [System.Drawing.Color]::FromArgb(42, 48, 58)
        Border       = [System.Drawing.Color]::FromArgb(62, 70, 82)
        Text         = [System.Drawing.Color]::FromArgb(242, 245, 249)
        Muted        = [System.Drawing.Color]::FromArgb(158, 168, 180)
        Accent       = [System.Drawing.Color]::FromArgb(76, 194, 149)
        AccentDark   = [System.Drawing.Color]::FromArgb(38, 132, 93)
        AccentBlue   = [System.Drawing.Color]::FromArgb(90, 147, 255)
        Warning      = [System.Drawing.Color]::FromArgb(230, 171, 92)
        Danger       = [System.Drawing.Color]::FromArgb(224, 92, 86)
        Status       = [System.Drawing.Color]::FromArgb(13, 15, 19)
        Selection    = [System.Drawing.Color]::FromArgb(45, 79, 74)
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

function New-KapselCard {
    [CmdletBinding()]
    param(
        [System.Windows.Forms.DockStyle] $Dock = [System.Windows.Forms.DockStyle]::None,
        [int] $Width = 0,
        [int] $Height = 0,
        [System.Windows.Forms.Padding] $Padding = (New-Object System.Windows.Forms.Padding(14))
    )

    $colors = Get-KapselUiColors
    $panel = New-Object System.Windows.Forms.Panel
    $panel.BackColor = $colors.Surface
    $panel.Padding = $Padding
    $panel.Dock = $Dock
    if ($Width -gt 0) { $panel.Width = $Width }
    if ($Height -gt 0) { $panel.Height = $Height }
    return $panel
}

function New-KapselTextLabel {
    [CmdletBinding()]
    param(
        [string] $Text,
        [float] $Size = 9,
        [System.Drawing.Color] $Color = (Get-KapselUiColors).Text,
        [System.Drawing.FontStyle] $Style = [System.Drawing.FontStyle]::Regular,
        [int] $Height = 22,
        [System.Windows.Forms.DockStyle] $Dock = [System.Windows.Forms.DockStyle]::Top
    )

    $label = New-Object System.Windows.Forms.Label
    $label.Text = $Text
    $label.Dock = $Dock
    $label.Height = $Height
    $label.ForeColor = $Color
    $label.Font = New-KapselFont -Size $Size -Style $Style
    $label.AutoEllipsis = $true
    return $label
}

function New-KapselSectionLabel {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string] $Text
    )

    $colors = Get-KapselUiColors
    return New-KapselTextLabel -Text $Text -Size 8 -Color $colors.Muted -Height 18
}

function New-KapselButton {
    [CmdletBinding()]
    param(
        [string] $Text,
        [System.Drawing.Color] $BackColor = (Get-KapselUiColors).SurfaceAlt,
        [int] $Width = 154
    )

    $colors = Get-KapselUiColors
    $button = New-Object System.Windows.Forms.Button
    $button.Text = $Text
    $button.Width = $Width
    $button.Height = 36
    $button.Margin = New-Object System.Windows.Forms.Padding(0, 0, 10, 0)
    $button.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $button.FlatAppearance.BorderColor = $colors.Border
    $button.FlatAppearance.MouseOverBackColor = $colors.SurfaceSoft
    $button.FlatAppearance.MouseDownBackColor = $colors.AccentDark
    $button.BackColor = $BackColor
    $button.ForeColor = $colors.Text
    $button.Font = New-KapselFont -Size 9
    return $button
}

function New-KapselBadge {
    [CmdletBinding()]
    param(
        [AllowEmptyString()]
        [string] $Text,
        [bool] $Enabled = $true
    )

    $colors = Get-KapselUiColors
    $badge = New-Object System.Windows.Forms.Label
    $badge.Text = $Text
    $badge.Width = 92
    $badge.Height = 24
    $badge.Margin = New-Object System.Windows.Forms.Padding(0, 0, 8, 8)
    $badge.TextAlign = [System.Drawing.ContentAlignment]::MiddleCenter
    $badge.Font = New-KapselFont -Size 8
    $badge.ForeColor = $colors.Text
    $badge.BackColor = if ($Enabled) { $colors.AccentDark } else { $colors.SurfaceSoft }
    return $badge
}

function New-KapselStat {
    [CmdletBinding()]
    param(
        [string] $Title,
        [string] $Value,
        [System.Drawing.Color] $AccentColor = (Get-KapselUiColors).Accent
    )

    $colors = Get-KapselUiColors
    $panel = New-KapselCard -Width 176 -Height 70 -Padding (New-Object System.Windows.Forms.Padding(12))
    $panel.Margin = New-Object System.Windows.Forms.Padding(0, 0, 12, 0)

    $accent = New-Object System.Windows.Forms.Panel
    $accent.BackColor = $AccentColor
    $accent.Dock = [System.Windows.Forms.DockStyle]::Left
    $accent.Width = 4

    $content = New-Object System.Windows.Forms.Panel
    $content.Dock = [System.Windows.Forms.DockStyle]::Fill
    $content.Padding = New-Object System.Windows.Forms.Padding(10, 0, 0, 0)
    $content.BackColor = $colors.Surface

    $titleLabel = New-KapselTextLabel -Text $Title -Size 8 -Color $colors.Muted -Height 20
    $valueLabel = New-KapselTextLabel -Text $Value -Size 14 -Color $colors.Text -Style ([System.Drawing.FontStyle]::Bold) -Height 30
    $content.Controls.AddRange(@($valueLabel, $titleLabel))
    $panel.Controls.AddRange(@($content, $accent))
    return $panel
}

function New-KapselBrandImageView {
    [CmdletBinding()]
    param(
        [string] $ImagePath,
        [int] $Size = 48
    )

    $colors = Get-KapselUiColors
    if ([string]::IsNullOrWhiteSpace($ImagePath) -or -not (Test-Path -LiteralPath $ImagePath)) {
        return $null
    }

    $picture = New-Object System.Windows.Forms.PictureBox
    $picture.Width = $Size
    $picture.Height = $Size
    $picture.BackColor = $colors.Surface
    $picture.SizeMode = [System.Windows.Forms.PictureBoxSizeMode]::Zoom
    $picture.Image = [System.Drawing.Image]::FromFile($ImagePath)
    return $picture
}

function New-KapselVisualTextPanel {
    [CmdletBinding()]
    param(
        [string[]] $Lines = @(),
        [System.Windows.Forms.DockStyle] $Dock = [System.Windows.Forms.DockStyle]::Fill
    )

    $colors = Get-KapselUiColors
    $panel = New-Object System.Windows.Forms.FlowLayoutPanel
    $panel.Dock = $Dock
    $panel.FlowDirection = [System.Windows.Forms.FlowDirection]::TopDown
    $panel.WrapContents = $false
    $panel.AutoScroll = $true
    $panel.BackColor = $colors.Surface
    $panel.Padding = New-Object System.Windows.Forms.Padding(12)

    foreach ($line in $Lines) {
        Add-KapselVisualLine -Panel $panel -Text $line
    }

    return $panel
}

function Add-KapselVisualLine {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [System.Windows.Forms.Control] $Panel,
        [AllowEmptyString()]
        [string] $Text,
        [System.Drawing.Color] $Color = (Get-KapselUiColors).Text,
        [float] $Size = 8.5,
        [System.Drawing.FontStyle] $Style = [System.Drawing.FontStyle]::Regular
    )

    if ([string]::IsNullOrEmpty($Text)) {
        $Text = ' '
    }

    if ($Panel -is [System.Windows.Forms.TextBox]) {
        $timestamp = Get-Date -Format 'HH:mm:ss'
        $Panel.AppendText(("[{0}] {1}{2}" -f $timestamp, $Text, [Environment]::NewLine))
        return
    }

    $label = New-KapselTextLabel -Text $Text -Size $Size -Color $Color -Style $Style -Height 22 -Dock ([System.Windows.Forms.DockStyle]::None)
    $label.Width = [Math]::Max(260, $Panel.ClientSize.Width - 36)
    $label.Margin = New-Object System.Windows.Forms.Padding(0, 0, 0, 4)
    $Panel.Controls.Add($label)
    $Panel.ScrollControlIntoView($label)
}

function Set-KapselTextBoxCueBanner {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [System.Windows.Forms.TextBox] $TextBox,
        [Parameter(Mandatory = $true)]
        [string] $Text
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

function Set-KapselDarkTabControl {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [System.Windows.Forms.TabControl] $TabControl
    )

    $TabControl.DrawMode = [System.Windows.Forms.TabDrawMode]::OwnerDrawFixed
    $TabControl.Add_DrawItem({
        param($sender, $eventArgs)

        $colors = Get-KapselUiColors
        $isSelected = $eventArgs.Index -eq $sender.SelectedIndex
        $bounds = $sender.GetTabRect($eventArgs.Index)
        $backColor = if ($isSelected) { $colors.Surface } else { $colors.SurfaceAlt }
        $foreColor = if ($isSelected) { $colors.Text } else { $colors.Muted }

        $brush = New-Object System.Drawing.SolidBrush($backColor)
        $eventArgs.Graphics.FillRectangle($brush, $bounds)
        $brush.Dispose()

        $flags = [System.Windows.Forms.TextFormatFlags]::HorizontalCenter -bor
            [System.Windows.Forms.TextFormatFlags]::VerticalCenter -bor
            [System.Windows.Forms.TextFormatFlags]::EndEllipsis
        [System.Windows.Forms.TextRenderer]::DrawText(
            $eventArgs.Graphics,
            [string] $sender.TabPages[$eventArgs.Index].Text,
            $sender.Font,
            $bounds,
            $foreColor,
            $flags
        )
    })
}

function Set-KapselDarkTreeView {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [System.Windows.Forms.TreeView] $TreeView
    )

    $TreeView.DrawMode = [System.Windows.Forms.TreeViewDrawMode]::OwnerDrawText
    $TreeView.Add_DrawNode({
        param($sender, $eventArgs)

        $colors = Get-KapselUiColors
        $isSelected = ($eventArgs.State -band [System.Windows.Forms.TreeNodeStates]::Selected) -eq [System.Windows.Forms.TreeNodeStates]::Selected
        $clientWidth = [int] $sender.ClientSize.Width
        $itemHeight = [int] $sender.ItemHeight
        $nodeTop = [int] $eventArgs.Bounds.Top
        $bounds = New-Object System.Drawing.Rectangle(0, $nodeTop, $clientWidth, $itemHeight)
        $backColor = if ($isSelected) { $colors.Selection } else { $colors.Surface }
        $foreColor = if ($isSelected) { $colors.Text } else { $colors.Muted }

        $backBrush = New-Object System.Drawing.SolidBrush($backColor)
        $eventArgs.Graphics.FillRectangle($backBrush, $bounds)
        $backBrush.Dispose()

        $textWidth = [Math]::Max(24, $clientWidth - 18)
        $textBounds = New-Object System.Drawing.Rectangle(12, $nodeTop, $textWidth, $itemHeight)
        $flags = [System.Windows.Forms.TextFormatFlags]::VerticalCenter -bor
            [System.Windows.Forms.TextFormatFlags]::EndEllipsis -bor
            [System.Windows.Forms.TextFormatFlags]::NoPrefix
        [System.Windows.Forms.TextRenderer]::DrawText(
            $eventArgs.Graphics,
            [string] $eventArgs.Node.Text,
            $sender.Font,
            $textBounds,
            $foreColor,
            $flags
        )
    })
}
function Write-KapselLog {
    [CmdletBinding()]
    param(
        [System.Windows.Forms.Control] $LogBox,
        [string] $Message
    )

    $colors = Get-KapselUiColors
    $timestamp = Get-Date -Format 'HH:mm:ss'
    Add-KapselVisualLine -Panel $LogBox -Text ("[{0}] {1}" -f $timestamp, $Message) -Color $colors.Muted
}

Export-ModuleMember -Function @(
    'Get-KapselUiColors',
    'Get-KapselUiFontFamily',
    'Initialize-KapselUiTheme',
    'New-KapselFont',
    'New-KapselCard',
    'New-KapselTextLabel',
    'New-KapselButton',
    'New-KapselBadge',
    'New-KapselBrandImageView',
    'New-KapselSectionLabel',
    'New-KapselStat',
    'New-KapselVisualTextPanel',
    'Set-KapselTextBoxCueBanner',
    'Set-KapselDarkTabControl',
    'Set-KapselDarkTreeView',
    'Add-KapselVisualLine',
    'Write-KapselLog'
)





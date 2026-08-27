# Borderless window behavior and custom title-bar controls for the WinForms shell.
Set-StrictMode -Version Latest

Import-Module (Join-Path $PSScriptRoot 'Theme.psm1') -Force

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

function Initialize-KapselBorderlessFormType {
    [CmdletBinding()]
    param()

    if ('Kapsel.Presentation.BorderlessForm' -as [type]) { return }

    Add-Type -ReferencedAssemblies @('System.Windows.Forms', 'System.Drawing') -TypeDefinition @"
using System;
using System.Drawing;
using System.Runtime.InteropServices;
using System.Windows.Forms;

namespace Kapsel.Presentation {
    public sealed class BorderlessForm : Form {
        private const int WmNcHitTest = 0x0084;
        private const int HtLeft = 10;
        private const int HtRight = 11;
        private const int HtTop = 12;
        private const int HtTopLeft = 13;
        private const int HtTopRight = 14;
        private const int HtBottom = 15;
        private const int HtBottomLeft = 16;
        private const int HtBottomRight = 17;
        private const int ResizeBorder = 7;

        public BorderlessForm() {
            FormBorderStyle = FormBorderStyle.None;
            SetStyle(
                ControlStyles.AllPaintingInWmPaint |
                ControlStyles.OptimizedDoubleBuffer |
                ControlStyles.ResizeRedraw,
                true
            );
        }

        protected override void WndProc(ref Message message) {
            if (message.Msg == WmNcHitTest && WindowState == FormWindowState.Normal) {
                int packedPoint = unchecked((int)message.LParam.ToInt64());
                int screenX = (short)(packedPoint & 0xffff);
                int screenY = (short)((packedPoint >> 16) & 0xffff);
                Point clientPoint = PointToClient(new Point(screenX, screenY));

                bool left = clientPoint.X <= ResizeBorder;
                bool right = clientPoint.X >= ClientSize.Width - ResizeBorder;
                bool top = clientPoint.Y <= ResizeBorder;
                bool bottom = clientPoint.Y >= ClientSize.Height - ResizeBorder;

                if (left && top) { message.Result = (IntPtr)HtTopLeft; return; }
                if (right && top) { message.Result = (IntPtr)HtTopRight; return; }
                if (left && bottom) { message.Result = (IntPtr)HtBottomLeft; return; }
                if (right && bottom) { message.Result = (IntPtr)HtBottomRight; return; }
                if (left) { message.Result = (IntPtr)HtLeft; return; }
                if (right) { message.Result = (IntPtr)HtRight; return; }
                if (top) { message.Result = (IntPtr)HtTop; return; }
                if (bottom) { message.Result = (IntPtr)HtBottom; return; }
            }

            base.WndProc(ref message);
        }
    }

    public static class WindowCommands {
        [DllImport("user32.dll")]
        public static extern bool ReleaseCapture();

        [DllImport("user32.dll")]
        public static extern IntPtr SendMessage(
            IntPtr window,
            int message,
            IntPtr wordParameter,
            IntPtr longParameter
        );
    }
}
"@
}

function New-KapselBorderlessForm {
    [CmdletBinding()]
    param([Parameter(Mandatory = $true)] [object] $Metadata)

    Initialize-KapselBorderlessFormType
    $colors = Get-KapselUiColors
    $form = New-Object Kapsel.Presentation.BorderlessForm
    $form.Text = [string] $Metadata.Name
    $form.Name = 'KapselMainWindow'
    $form.AccessibleName = [string] $Metadata.Name
    $form.StartPosition = [System.Windows.Forms.FormStartPosition]::CenterScreen
    $form.MinimumSize = New-Object System.Drawing.Size(1180, 700)
    $form.Size = New-Object System.Drawing.Size(1440, 840)
    $form.BackColor = $colors.Border
    $form.Padding = New-Object System.Windows.Forms.Padding(1)
    $form.Font = New-KapselFont -Size 8.5
    $form.KeyPreview = $true
    return $form
}

function New-KapselWindowButton {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)] [string] $Name,
        [Parameter(Mandatory = $true)] [string] $AccessibleName,
        [Parameter(Mandatory = $true)] [char] $Glyph,
        [switch] $IsCloseButton
    )

    $colors = Get-KapselUiColors
    $button = New-Object System.Windows.Forms.Button
    $button.Name = $Name
    $button.AccessibleName = $AccessibleName
    $button.Text = [string] $Glyph
    $button.Dock = [System.Windows.Forms.DockStyle]::Fill
    $button.Margin = New-Object System.Windows.Forms.Padding(0)
    $button.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $button.FlatAppearance.BorderSize = 0
    $button.FlatAppearance.MouseOverBackColor = if ($IsCloseButton) { $colors.Danger } else { $colors.SurfaceAlt }
    $button.FlatAppearance.MouseDownBackColor = if ($IsCloseButton) { [System.Drawing.Color]::FromArgb(184, 72, 81) } else { $colors.SurfaceSoft }
    $button.BackColor = $colors.Window
    $button.ForeColor = $colors.Text
    $button.Font = New-Object System.Drawing.Font('Segoe MDL2 Assets', 9, [System.Drawing.FontStyle]::Regular)
    $button.TabStop = $false
    $button.UseVisualStyleBackColor = $false
    return $button
}

function Set-KapselMaximizedState {
    [CmdletBinding()]
    param([Parameter(Mandatory = $true)] [System.Windows.Forms.Form] $Form)

    if ($Form.WindowState -eq [System.Windows.Forms.FormWindowState]::Maximized) {
        $Form.WindowState = [System.Windows.Forms.FormWindowState]::Normal
        return
    }

    $Form.WindowState = [System.Windows.Forms.FormWindowState]::Maximized
}

function New-KapselWindowTitleBar {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)] [System.Windows.Forms.Form] $Form,
        [Parameter(Mandatory = $true)] [object] $Metadata
    )

    $colors = Get-KapselUiColors
    $titleBar = New-Object System.Windows.Forms.TableLayoutPanel
    $titleBar.Name = 'KapselTitleBar'
    $titleBar.AccessibleName = 'Application title bar'
    $titleBar.Dock = [System.Windows.Forms.DockStyle]::Fill
    $titleBar.Margin = New-Object System.Windows.Forms.Padding(0)
    $titleBar.Padding = New-Object System.Windows.Forms.Padding(10, 0, 0, 0)
    $titleBar.BackColor = $colors.Window
    $titleBar.ColumnCount = 4
    $titleBar.RowCount = 1
    [void] $titleBar.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Percent, 100)))
    foreach ($index in 1..3) {
        [void] $titleBar.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Absolute, 46)))
    }

    $title = New-KapselLabel -Text "$($Metadata.Name)  $($Metadata.Version)" -Size 7.5 -Color $colors.Muted -Height 38 -Dock ([System.Windows.Forms.DockStyle]::Fill)
    $title.Name = 'KapselWindowTitle'
    $title.AccessibleName = "$($Metadata.Name) window title"
    $title.Padding = New-Object System.Windows.Forms.Padding(2, 0, 0, 0)

    $minimizeButton = New-KapselWindowButton -Name 'KapselMinimizeButton' -AccessibleName 'Minimize window' -Glyph ([char] 0xE921)
    $maximizeButton = New-KapselWindowButton -Name 'KapselMaximizeButton' -AccessibleName 'Maximize window' -Glyph ([char] 0xE922)
    $closeButton = New-KapselWindowButton -Name 'KapselCloseButton' -AccessibleName 'Close window' -Glyph ([char] 0xE8BB) -IsCloseButton

    $titleBar.Controls.Add($title, 0, 0)
    $titleBar.Controls.Add($minimizeButton, 1, 0)
    $titleBar.Controls.Add($maximizeButton, 2, 0)
    $titleBar.Controls.Add($closeButton, 3, 0)

    $toggleMaximize = {
        param($sender, $eventArgs)

        Set-KapselMaximizedState -Form $sender.FindForm()
    }
    $dragWindow = [System.Windows.Forms.MouseEventHandler] {
        param($sender, $eventArgs)

        if ($eventArgs.Button -ne [System.Windows.Forms.MouseButtons]::Left) { return }
        $eventForm = $sender.FindForm()
        [void] [Kapsel.Presentation.WindowCommands]::ReleaseCapture()
        [void] [Kapsel.Presentation.WindowCommands]::SendMessage($eventForm.Handle, 0x00A1, [IntPtr] 2, [IntPtr]::Zero)
    }
    $titleBar.Add_MouseDown($dragWindow)
    $title.Add_MouseDown($dragWindow)
    $titleBar.Add_DoubleClick($toggleMaximize)
    $title.Add_DoubleClick($toggleMaximize)
    $minimizeButton.Add_Click({
        param($sender, $eventArgs)

        $sender.FindForm().WindowState = [System.Windows.Forms.FormWindowState]::Minimized
    })
    $maximizeButton.Add_Click($toggleMaximize)
    $closeButton.Add_Click({
        param($sender, $eventArgs)

        $sender.FindForm().Close()
    })
    $Form.Add_Resize({
        param($sender, $eventArgs)

        $button = $sender.Controls.Find('KapselMaximizeButton', $true) | Select-Object -First 1
        if ($null -eq $button) { return }
        $button.Text = if ($sender.WindowState -eq [System.Windows.Forms.FormWindowState]::Maximized) {
            [string][char] 0xE923
        }
        else {
            [string][char] 0xE922
        }
        $button.AccessibleName = if ($sender.WindowState -eq [System.Windows.Forms.FormWindowState]::Maximized) {
            'Restore window'
        }
        else {
            'Maximize window'
        }
    })

    $toolTip = New-Object System.Windows.Forms.ToolTip
    $toolTip.SetToolTip($minimizeButton, 'Minimize')
    $toolTip.SetToolTip($maximizeButton, 'Maximize or restore')
    $toolTip.SetToolTip($closeButton, 'Close')
    $titleBar.Tag = $toolTip
    $titleBar.Add_Disposed({
        param($sender, $eventArgs)

        if ($sender.Tag -is [System.Windows.Forms.ToolTip]) {
            $sender.Tag.Dispose()
            $sender.Tag = $null
        }
    })

    return [PSCustomObject] @{
        Panel          = $titleBar
        MinimizeButton = $minimizeButton
        MaximizeButton = $maximizeButton
        CloseButton    = $closeButton
    }
}

Export-ModuleMember -Function @(
    'New-KapselBorderlessForm',
    'New-KapselWindowTitleBar',
    'Set-KapselMaximizedState'
)

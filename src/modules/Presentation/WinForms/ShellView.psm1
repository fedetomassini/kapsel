# Compact three-pane desktop shell for catalog, navigation, and contextual results.
Set-StrictMode -Version Latest

Import-Module (Join-Path $PSScriptRoot 'Theme.psm1') -Force
Import-Module (Join-Path $PSScriptRoot 'WindowChrome.psm1') -Force

Add-Type -AssemblyName System.Windows.Forms

function New-KapselShellView {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)] [System.Windows.Forms.Form] $Form,
        [Parameter(Mandatory = $true)] [System.Windows.Forms.Control] $Sidebar,
        [Parameter(Mandatory = $true)] [System.Windows.Forms.Control] $Catalog,
        [Parameter(Mandatory = $true)] [System.Windows.Forms.Control] $Context,
        [Parameter(Mandatory = $true)] [object] $Metadata
    )

    $colors = Get-KapselUiColors
    $shell = New-Object System.Windows.Forms.TableLayoutPanel
    $shell.Dock = [System.Windows.Forms.DockStyle]::Fill
    $shell.BackColor = $colors.Border
    $shell.Padding = New-Object System.Windows.Forms.Padding(0)
    $shell.Margin = New-Object System.Windows.Forms.Padding(0)
    $shell.ColumnCount = 3
    $shell.RowCount = 3
    [void] $shell.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Absolute, 252)))
    [void] $shell.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Percent, 100)))
    [void] $shell.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Absolute, 292)))
    [void] $shell.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 38)))
    [void] $shell.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Percent, 100)))
    [void] $shell.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 30)))

    foreach ($control in @($Sidebar, $Catalog, $Context)) {
        $control.Margin = New-Object System.Windows.Forms.Padding(0)
    }

    $status = New-Object System.Windows.Forms.TableLayoutPanel
    $status.Dock = [System.Windows.Forms.DockStyle]::Fill
    $status.Margin = New-Object System.Windows.Forms.Padding(0, 1, 0, 0)
    $status.Padding = New-Object System.Windows.Forms.Padding(12, 0, 12, 0)
    $status.BackColor = $colors.Window
    $status.ColumnCount = 4
    [void] $status.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Percent, 100)))
    [void] $status.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Absolute, 150)))
    [void] $status.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Absolute, 80)))
    [void] $status.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::AutoSize)))
    $statusLabel = New-KapselLabel -Text 'Ready' -Size 7 -Color $colors.Muted -Height 28 -Dock ([System.Windows.Forms.DockStyle]::Fill)
    $versionLabel = New-KapselLabel -Text "$($Metadata.Name) $($Metadata.Version)" -Size 7 -Color $colors.Subtle -Height 28 -Dock ([System.Windows.Forms.DockStyle]::Fill) -TextAlign ([System.Drawing.ContentAlignment]::MiddleRight)
    $status.Controls.Add($statusLabel, 0, 0)
    $batchProgress = New-Object System.Windows.Forms.ProgressBar
    $batchProgress.Name = 'KapselBatchProgress'
    $batchProgress.AccessibleName = 'Completed applications'
    $batchProgress.Dock = [System.Windows.Forms.DockStyle]::Fill
    $batchProgress.Margin = New-Object System.Windows.Forms.Padding(6)
    $batchProgress.Visible = $false
    $currentProgress = New-Object System.Windows.Forms.ProgressBar
    $currentProgress.AccessibleName = 'Current application running'
    $currentProgress.Dock = [System.Windows.Forms.DockStyle]::Fill
    $currentProgress.Margin = New-Object System.Windows.Forms.Padding(6)
    $currentProgress.Style = [System.Windows.Forms.ProgressBarStyle]::Marquee
    $currentProgress.Visible = $false
    $status.Controls.Add($batchProgress, 1, 0)
    $status.Controls.Add($currentProgress, 2, 0)
    $status.Controls.Add($versionLabel, 3, 0)

    $windowChrome = New-KapselWindowTitleBar -Form $Form -Metadata $Metadata
    $shell.Controls.Add($windowChrome.Panel, 0, 0)
    $shell.SetColumnSpan($windowChrome.Panel, 3)
    $shell.Controls.Add($Sidebar, 0, 1)
    $shell.Controls.Add($Catalog, 1, 1)
    $shell.Controls.Add($Context, 2, 1)
    $shell.Controls.Add($status, 0, 2)
    $shell.SetColumnSpan($status, 3)

    return [PSCustomObject] @{
        Panel       = $shell
        StatusLabel = $statusLabel
        BatchProgress = $batchProgress
        CurrentProgress = $currentProgress
        WindowChrome = $windowChrome
    }
}

Export-ModuleMember -Function 'New-KapselShellView'

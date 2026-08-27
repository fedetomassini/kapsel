# Catalog grid view and selection projection.
Set-StrictMode -Version Latest

Import-Module (Join-Path $PSScriptRoot 'Theme.psm1') -Force

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

function New-KapselApplicationTable {
    [CmdletBinding()]
    param(
        [object[]] $Applications = @(),
        [string[]] $SelectedKeys = @()
    )

    $table = New-Object System.Data.DataTable
    [void] $table.Columns.Add('Selected', [bool])
    [void] $table.Columns.Add('Key', [string])
    [void] $table.Columns.Add('Name', [string])
    [void] $table.Columns.Add('Category', [string])
    [void] $table.Columns.Add('Providers', [string])
    [void] $table.Columns.Add('FOSS', [string])
    [void] $table.Columns.Add('Description', [string])

    foreach ($application in @($Applications)) {
        $providers = @()
        if ($application.WingetId) { $providers += 'winget' }
        if ($application.ChocoId) { $providers += 'choco' }
        [void] $table.Rows.Add(
            ($SelectedKeys -contains [string] $application.Key),
            $application.Key,
            $application.Name,
            $application.Category,
            ($providers -join ' / '),
            $(if ($application.Foss) { 'Yes' } else { 'No' }),
            $application.Description
        )
    }

    return ,$table
}

function New-KapselApplicationGrid {
    [CmdletBinding()]
    param()

    $colors = Get-KapselUiColors
    $grid = New-Object System.Windows.Forms.DataGridView
    $grid.Dock = [System.Windows.Forms.DockStyle]::Fill
    $grid.AutoGenerateColumns = $false
    $grid.AllowUserToAddRows = $false
    $grid.AllowUserToDeleteRows = $false
    $grid.AllowUserToResizeRows = $false
    $grid.MultiSelect = $false
    $grid.ReadOnly = $false
    $grid.SelectionMode = [System.Windows.Forms.DataGridViewSelectionMode]::FullRowSelect
    $grid.BackgroundColor = $colors.Main
    $grid.BorderStyle = [System.Windows.Forms.BorderStyle]::None
    $grid.ScrollBars = [System.Windows.Forms.ScrollBars]::None
    $grid.CellBorderStyle = [System.Windows.Forms.DataGridViewCellBorderStyle]::SingleHorizontal
    $grid.ColumnHeadersBorderStyle = [System.Windows.Forms.DataGridViewHeaderBorderStyle]::None
    $grid.GridColor = $colors.Border
    $grid.RowHeadersVisible = $false
    $grid.EnableHeadersVisualStyles = $false
    $grid.ColumnHeadersHeight = 36
    $grid.ColumnHeadersHeightSizeMode = [System.Windows.Forms.DataGridViewColumnHeadersHeightSizeMode]::DisableResizing
    $grid.RowTemplate.Height = 36
    $grid.EditMode = [System.Windows.Forms.DataGridViewEditMode]::EditOnEnter
    $grid.ColumnHeadersDefaultCellStyle.BackColor = $colors.Surface
    $grid.ColumnHeadersDefaultCellStyle.ForeColor = $colors.Muted
    $grid.ColumnHeadersDefaultCellStyle.SelectionBackColor = $colors.Surface
    $grid.ColumnHeadersDefaultCellStyle.SelectionForeColor = $colors.Text
    $grid.ColumnHeadersDefaultCellStyle.Font = New-KapselFont -Size 8 -Style ([System.Drawing.FontStyle]::Bold)
    $grid.DefaultCellStyle.BackColor = $colors.Main
    $grid.DefaultCellStyle.ForeColor = $colors.Text
    $grid.DefaultCellStyle.SelectionBackColor = $colors.Selection
    $grid.DefaultCellStyle.SelectionForeColor = $colors.Text
    $grid.DefaultCellStyle.Font = New-KapselFont -Size 8
    $grid.DefaultCellStyle.Padding = New-Object System.Windows.Forms.Padding(4, 0, 4, 0)
    $grid.AlternatingRowsDefaultCellStyle.BackColor = $colors.Sidebar
    Add-KapselGridScrollbar -Grid $grid
    return $grid
}

function Update-KapselGridScrollbar {
    [CmdletBinding()]
    param([Parameter(Mandatory = $true)] [System.Windows.Forms.DataGridView] $Grid)

    $state = $Grid.Tag
    if ($null -eq $state -or $null -eq $state.Track -or $state.Track.IsDisposed) { return }

    $totalRows = [int] $Grid.Rows.Count
    $visibleRows = if ($totalRows -gt 0) { [int] $Grid.DisplayedRowCount($false) } else { 0 }
    $trackHeight = [int] $state.Track.ClientSize.Height
    $requiresScroll = $totalRows -gt $visibleRows -and $trackHeight -gt 0
    $state.Track.Visible = $requiresScroll
    if (-not $requiresScroll) { return }

    $thumbHeight = [Math]::Max(34, [int] [Math]::Floor($trackHeight * ($visibleRows / [double] $totalRows)))
    $thumbHeight = [Math]::Min($trackHeight, $thumbHeight)
    $maximumTop = [Math]::Max(0, $trackHeight - $thumbHeight)
    $maximumRow = [Math]::Max(1, $totalRows - $visibleRows)
    $firstRow = [Math]::Max(0, [int] $Grid.FirstDisplayedScrollingRowIndex)
    $thumbTop = [int] [Math]::Round($maximumTop * ($firstRow / [double] $maximumRow))
    $state.Thumb.SetBounds(2, $thumbTop, [Math]::Max(4, $state.Track.ClientSize.Width - 4), $thumbHeight)
    $state.Thumb.BringToFront()
}

function Set-KapselGridScrollPosition {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)] [object] $State,
        [Parameter(Mandatory = $true)] [int] $ThumbTop
    )

    $grid = $State.Grid
    $visibleRows = [int] $grid.DisplayedRowCount($false)
    $maximumRow = [Math]::Max(0, $grid.Rows.Count - $visibleRows)
    $maximumTop = [Math]::Max(0, $State.Track.ClientSize.Height - $State.Thumb.Height)
    if ($maximumRow -eq 0 -or $maximumTop -eq 0) { return }

    $boundedTop = [Math]::Max(0, [Math]::Min($maximumTop, $ThumbTop))
    $targetRow = [int] [Math]::Round($maximumRow * ($boundedTop / [double] $maximumTop))
    $grid.FirstDisplayedScrollingRowIndex = [Math]::Max(0, [Math]::Min($grid.Rows.Count - 1, $targetRow))
    Update-KapselGridScrollbar -Grid $grid
}

function Add-KapselGridScrollbar {
    [CmdletBinding()]
    param([Parameter(Mandatory = $true)] [System.Windows.Forms.DataGridView] $Grid)

    $colors = Get-KapselUiColors
    $track = New-Object System.Windows.Forms.Panel
    $track.Name = 'KapselGridScrollTrack'
    $track.AccessibleName = 'Catalog scrollbar'
    $track.Dock = [System.Windows.Forms.DockStyle]::Right
    $track.Width = 12
    $track.Padding = New-Object System.Windows.Forms.Padding(2, 0, 2, 0)
    $track.BackColor = $colors.Surface
    $track.Cursor = [System.Windows.Forms.Cursors]::Hand

    $thumb = New-Object System.Windows.Forms.Panel
    $thumb.Name = 'KapselGridScrollThumb'
    $thumb.AccessibleName = 'Catalog scrollbar thumb'
    $thumb.BackColor = $colors.Subtle
    $thumb.Cursor = [System.Windows.Forms.Cursors]::Hand
    $track.Controls.Add($thumb)

    $state = [PSCustomObject] @{
        Grid       = $Grid
        Track      = $track
        Thumb      = $thumb
        Dragging   = $false
        DragOffset = 0
    }
    $Grid.Tag = $state
    $track.Tag = $state
    $thumb.Tag = $state
    $Grid.Controls.Add($track)

    $track.Add_MouseDown({
        param($sender, $eventArgs)

        $eventState = $sender.Tag
        Set-KapselGridScrollPosition -State $eventState -ThumbTop ($eventArgs.Y - [int] ($eventState.Thumb.Height / 2))
    })
    $thumb.Add_MouseDown({
        param($sender, $eventArgs)

        if ($eventArgs.Button -ne [System.Windows.Forms.MouseButtons]::Left) { return }
        $sender.Tag.Dragging = $true
        $sender.Tag.DragOffset = $eventArgs.Y
        $sender.Capture = $true
    })
    $thumb.Add_MouseMove({
        param($sender, $eventArgs)

        $eventState = $sender.Tag
        if (-not $eventState.Dragging) { return }
        $trackPoint = $eventState.Track.PointToClient($sender.PointToScreen($eventArgs.Location))
        Set-KapselGridScrollPosition -State $eventState -ThumbTop ($trackPoint.Y - $eventState.DragOffset)
    })
    $thumb.Add_MouseUp({
        param($sender, $eventArgs)

        $sender.Tag.Dragging = $false
        $sender.Capture = $false
    })
    $Grid.Add_MouseWheel({
        param($sender, $eventArgs)

        if ($sender.Rows.Count -eq 0) { return }
        $visibleRows = [int] $sender.DisplayedRowCount($false)
        $maximumRow = [Math]::Max(0, $sender.Rows.Count - $visibleRows)
        $currentRow = [Math]::Max(0, [int] $sender.FirstDisplayedScrollingRowIndex)
        $direction = if ($eventArgs.Delta -gt 0) { -3 } else { 3 }
        $sender.FirstDisplayedScrollingRowIndex = [Math]::Max(0, [Math]::Min($maximumRow, $currentRow + $direction))
        if ($eventArgs -is [System.Windows.Forms.HandledMouseEventArgs]) { $eventArgs.Handled = $true }
        Update-KapselGridScrollbar -Grid $sender
    })
    $Grid.Add_Scroll({
        param($sender, $eventArgs)
        Update-KapselGridScrollbar -Grid $sender
    })
    $Grid.Add_Resize({
        param($sender, $eventArgs)
        Update-KapselGridScrollbar -Grid $sender
    })
    $Grid.Add_DataBindingComplete({
        param($sender, $eventArgs)
        Update-KapselGridScrollbar -Grid $sender
    })
}

function Initialize-KapselApplicationGridColumns {
    param([Parameter(Mandatory = $true)] [System.Windows.Forms.DataGridView] $Grid)

    if ($Grid.Columns.Count -gt 0) { return }

    $selectedColumn = New-Object System.Windows.Forms.DataGridViewCheckBoxColumn
    $selectedColumn.Name = 'Selected'
    $selectedColumn.HeaderText = ''
    $selectedColumn.DataPropertyName = 'Selected'
    $selectedColumn.Width = 38
    $selectedColumn.ReadOnly = $false
    $selectedColumn.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    [void] $Grid.Columns.Add($selectedColumn)

    foreach ($column in @(
        [PSCustomObject] @{ Name = 'Key'; Header = 'Key'; Width = 70; Visible = $false; Fill = $false },
        [PSCustomObject] @{ Name = 'Name'; Header = 'Application'; Width = 190; Visible = $true; Fill = $false },
        [PSCustomObject] @{ Name = 'Category'; Header = 'Category'; Width = 115; Visible = $true; Fill = $false },
        [PSCustomObject] @{ Name = 'Providers'; Header = 'Providers'; Width = 105; Visible = $true; Fill = $false },
        [PSCustomObject] @{ Name = 'FOSS'; Header = 'FOSS'; Width = 54; Visible = $true; Fill = $false },
        [PSCustomObject] @{ Name = 'Description'; Header = 'Description'; Width = 320; Visible = $true; Fill = $true }
    )) {
        $gridColumn = New-Object System.Windows.Forms.DataGridViewTextBoxColumn
        $gridColumn.Name = $column.Name
        $gridColumn.HeaderText = $column.Header
        $gridColumn.DataPropertyName = $column.Name
        $gridColumn.Width = $column.Width
        $gridColumn.Visible = $column.Visible
        $gridColumn.ReadOnly = $true
        if ($column.Fill) {
            $gridColumn.AutoSizeMode = [System.Windows.Forms.DataGridViewAutoSizeColumnMode]::Fill
        }
        [void] $Grid.Columns.Add($gridColumn)
    }
}

function Set-KapselApplicationGrid {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)] [System.Windows.Forms.DataGridView] $Grid,
        [object[]] $Applications = @(),
        [string[]] $SelectedKeys = @()
    )

    Initialize-KapselApplicationGridColumns -Grid $Grid
    $Grid.DataSource = New-KapselApplicationTable -Applications $Applications -SelectedKeys $SelectedKeys
}

function Get-KapselVisibleSelectionKeys {
    [CmdletBinding()]
    param([Parameter(Mandatory = $true)] [System.Windows.Forms.DataGridView] $Grid)

    $Grid.EndEdit()
    return @(
        foreach ($row in $Grid.Rows) {
            if (-not $row.IsNewRow -and $row.Cells['Selected'].Value -eq $true) {
                [string] $row.Cells['Key'].Value
            }
        }
    )
}

function Get-KapselCurrentApplicationKey {
    [CmdletBinding()]
    param([Parameter(Mandatory = $true)] [System.Windows.Forms.DataGridView] $Grid)

    if ($null -eq $Grid.CurrentRow -or $Grid.CurrentRow.IsNewRow) { return $null }
    return [string] $Grid.CurrentRow.Cells['Key'].Value
}

Export-ModuleMember -Function @(
    'New-KapselApplicationTable',
    'New-KapselApplicationGrid',
    'Set-KapselApplicationGrid',
    'Get-KapselVisibleSelectionKeys',
    'Get-KapselCurrentApplicationKey',
    'Update-KapselGridScrollbar',
    'Set-KapselGridScrollPosition'
)

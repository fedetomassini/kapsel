# Application table and grid helpers.
Set-StrictMode -Version Latest

Import-Module (Join-Path $PSScriptRoot 'UiTheme.psm1') -Force

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# Creates a DataTable from the provided applications, with columns for selection and metadata.
function New-KapselApplicationTable {
    [CmdletBinding()]
    param([object[]] $Applications)

    $table = New-Object System.Data.DataTable
    [void] $table.Columns.Add('Selected', [bool])
    [void] $table.Columns.Add('Key', [string])
    [void] $table.Columns.Add('Name', [string])
    [void] $table.Columns.Add('Category', [string])
    [void] $table.Columns.Add('Provider', [string])
    [void] $table.Columns.Add('WingetId', [string])
    [void] $table.Columns.Add('ChocoId', [string])
    [void] $table.Columns.Add('FOSS', [bool])
    [void] $table.Columns.Add('Description', [string])

    foreach ($application in @($Applications)) {
        [void] $table.Rows.Add(
            $false,
            $application.Key,
            $application.Name,
            $application.Category,
            $application.Provider,
            $application.WingetId,
            $application.ChocoId,
            $application.Foss,
            $application.Description
        )
    }

    return ,$table
}

# Creates and configures a new DataGridView for displaying applications.
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
    $grid.SelectionMode = [System.Windows.Forms.DataGridViewSelectionMode]::FullRowSelect
    $grid.BackgroundColor = $colors.Surface
    $grid.BorderStyle = [System.Windows.Forms.BorderStyle]::None
    $grid.CellBorderStyle = [System.Windows.Forms.DataGridViewCellBorderStyle]::SingleHorizontal
    $grid.GridColor = $colors.Border
    $grid.RowHeadersVisible = $false
    $grid.EnableHeadersVisualStyles = $false
    $grid.ColumnHeadersHeight = 34
    $grid.ColumnHeadersHeightSizeMode = [System.Windows.Forms.DataGridViewColumnHeadersHeightSizeMode]::DisableResizing
    $grid.RowTemplate.Height = 34
    $grid.EditMode = [System.Windows.Forms.DataGridViewEditMode]::EditOnEnter
    $grid.ColumnHeadersDefaultCellStyle.BackColor = $colors.SurfaceAlt
    $grid.ColumnHeadersDefaultCellStyle.ForeColor = $colors.Text
    $grid.ColumnHeadersDefaultCellStyle.SelectionBackColor = $colors.SurfaceAlt
    $grid.ColumnHeadersDefaultCellStyle.SelectionForeColor = $colors.Text
    $grid.ColumnHeadersDefaultCellStyle.Font = New-KapselFont -Size 9 -Style ([System.Drawing.FontStyle]::Bold)
    $grid.DefaultCellStyle.BackColor = $colors.Surface
    $grid.DefaultCellStyle.ForeColor = $colors.Text
    $grid.DefaultCellStyle.SelectionBackColor = $colors.Selection
    $grid.DefaultCellStyle.SelectionForeColor = $colors.Text
    $grid.DefaultCellStyle.Font = New-KapselFont -Size 8.5
    $grid.AlternatingRowsDefaultCellStyle.BackColor = [System.Drawing.Color]::FromArgb(31, 36, 43)
    $grid.AutoSizeRowsMode = [System.Windows.Forms.DataGridViewAutoSizeRowsMode]::None
    return $grid
}

# Configures the application grid with the provided applications and columns.
function Set-KapselApplicationGrid {
    [CmdletBinding()]
    param(
        [System.Windows.Forms.DataGridView] $Grid,
        [object[]] $Applications
    )

    if ($Grid.Columns.Count -eq 0) {
        $selectedColumn = New-Object System.Windows.Forms.DataGridViewCheckBoxColumn
        $selectedColumn.Name = 'Selected'
        $selectedColumn.HeaderText = ''
        $selectedColumn.DataPropertyName = 'Selected'
        $selectedColumn.Width = 42
        $selectedColumn.ReadOnly = $false
        [void] $Grid.Columns.Add($selectedColumn)

        foreach ($column in @(
            [PSCustomObject] @{ Name = 'Key'; Header = 'Key'; Width = 80; Visible = $false; Fill = $false },
            [PSCustomObject] @{ Name = 'Name'; Header = 'Application'; Width = 210; Visible = $true; Fill = $false },
            [PSCustomObject] @{ Name = 'Category'; Header = 'Category'; Width = 140; Visible = $true; Fill = $false },
            [PSCustomObject] @{ Name = 'Provider'; Header = 'Provider'; Width = 88; Visible = $true; Fill = $false },
            [PSCustomObject] @{ Name = 'WingetId'; Header = 'winget'; Width = 160; Visible = $false; Fill = $false },
            [PSCustomObject] @{ Name = 'ChocoId'; Header = 'choco'; Width = 150; Visible = $false; Fill = $false },
            [PSCustomObject] @{ Name = 'FOSS'; Header = 'FOSS'; Width = 64; Visible = $true; Fill = $false },
            [PSCustomObject] @{ Name = 'Description'; Header = 'Description'; Width = 360; Visible = $true; Fill = $true }
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

    $Grid.DataSource = New-KapselApplicationTable -Applications $Applications

    foreach ($columnName in @('Key', 'WingetId', 'ChocoId')) {
        if ($Grid.Columns.Contains($columnName)) {
            $Grid.Columns[$columnName].Visible = $false
        }
    }
}

# Retrieves the list of selected applications from the grid based on the 'Selected' checkbox column.
function Get-KapselSelectedApplications {
    [CmdletBinding()]
    param(
        [System.Windows.Forms.DataGridView] $Grid,
        [object[]] $Catalog
    )

    $Grid.EndEdit()
    $selectedKeys = New-Object System.Collections.Generic.List[string]
    foreach ($row in $Grid.Rows) {
        if (-not $row.IsNewRow -and $row.Cells['Selected'].Value -eq $true) {
            [void] $selectedKeys.Add([string] $row.Cells['Key'].Value)
        }
    }

    return @($Catalog | Where-Object { $selectedKeys -contains $_.Key })
}

Export-ModuleMember -Function @(
    'New-KapselApplicationTable',
    'New-KapselApplicationGrid',
    'Set-KapselApplicationGrid',
    'Get-KapselSelectedApplications'
)

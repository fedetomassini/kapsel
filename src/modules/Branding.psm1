# Product metadata used by the CLI, installer, and UI.
Set-StrictMode -Version Latest

# Just metadata
function Get-KapselMetadata {
    [CmdletBinding()]
    param()

    return [PSCustomObject] @{
        Name        = 'Kapsel'
        Version     = '1.0.0'
        Creator     = 'Federico Tomassini'
        Description = 'Windows application installer'
    }
}

Export-ModuleMember -Function 'Get-KapselMetadata'

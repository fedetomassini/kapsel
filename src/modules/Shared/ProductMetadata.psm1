# Stable product metadata shared by the entry point and UI.
Set-StrictMode -Version Latest

function Get-KapselProductMetadata {
    [CmdletBinding()]
    param()

    return [PSCustomObject] @{
        Name        = 'Kapsel'
        Version     = '1.4.0'
        Creator     = 'Federico Tomassini'
        Description = 'Curated application installer and updater for Windows'
    }
}

Export-ModuleMember -Function 'Get-KapselProductMetadata'

# Image and asset path helpers for Kapsel.
Set-StrictMode -Version Latest

function Get-KapselImagesPath {
    [CmdletBinding()]
    param()

    return Join-Path (Split-Path -Parent $PSScriptRoot) 'images'
}

function Get-KapselLogoPath {
    [CmdletBinding()]
    param()

    $imagesPath = Get-KapselImagesPath
    foreach ($fileName in @('logo.png', 'logo.jpg', 'logo.jpeg', 'logo.ico', 'kapsel.png', 'kapsel.ico')) {
        $path = Join-Path $imagesPath $fileName
        if (Test-Path -LiteralPath $path) {
            return $path
        }
    }

    return $null
}

Export-ModuleMember -Function @(
    'Get-KapselImagesPath',
    'Get-KapselLogoPath'
)

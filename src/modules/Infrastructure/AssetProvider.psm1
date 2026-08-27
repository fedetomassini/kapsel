# Optional image and window-icon adapter.
Set-StrictMode -Version Latest

Add-Type -AssemblyName System.Drawing

function Get-KapselProjectRoot {
    [CmdletBinding()]
    param()

    return Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSScriptRoot))
}

function Get-KapselBrandImagePath {
    [CmdletBinding()]
    param()

    $path = Join-Path (Get-KapselProjectRoot) 'assets\logo.png'
    if (Test-Path -LiteralPath $path -PathType Leaf) {
        return $path
    }
    return $null
}

function New-KapselWindowIcon {
    [CmdletBinding()]
    param([AllowNull()] [string] $ImagePath)

    if ([string]::IsNullOrWhiteSpace($ImagePath) -or -not (Test-Path -LiteralPath $ImagePath -PathType Leaf)) {
        return $null
    }

    if (-not ('Kapsel.AssetNativeMethods' -as [type])) {
        Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;

namespace Kapsel {
    public static class AssetNativeMethods {
        [DllImport("user32.dll", SetLastError = true)]
        public static extern bool DestroyIcon(IntPtr hIcon);
    }
}
"@
    }

    $bitmap = $null
    $sourceIcon = $null
    $handle = [IntPtr]::Zero

    try {
        $bitmap = New-Object System.Drawing.Bitmap($ImagePath)
        $handle = $bitmap.GetHicon()
        $sourceIcon = [System.Drawing.Icon]::FromHandle($handle)
        return $sourceIcon.Clone()
    }
    finally {
        if ($null -ne $sourceIcon) { $sourceIcon.Dispose() }
        if ($handle -ne [IntPtr]::Zero) { [Kapsel.AssetNativeMethods]::DestroyIcon($handle) | Out-Null }
        if ($null -ne $bitmap) { $bitmap.Dispose() }
    }
}

Export-ModuleMember -Function @(
    'Get-KapselProjectRoot',
    'Get-KapselBrandImagePath',
    'New-KapselWindowIcon'
)

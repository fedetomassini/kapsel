# Asset path helpers for Kapsel.
Set-StrictMode -Version Latest

Add-Type -AssemblyName System.Drawing

function Get-KapselAssetsPath {
    [CmdletBinding()]
    param()

    return Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'assets'
}

function Get-KapselBrandImagePath {
    [CmdletBinding()]
    param()

    $path = Join-Path (Get-KapselAssetsPath) 'logo.png'
    if (Test-Path -LiteralPath $path) {
        return $path
    }

    return $null
}

function New-KapselWindowIcon {
    [CmdletBinding()]
    param(
        [AllowNull()]
        [string] $ImagePath
    )

    if ([string]::IsNullOrWhiteSpace($ImagePath) -or -not (Test-Path -LiteralPath $ImagePath)) {
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
    $handle = [IntPtr]::Zero
    $icon = $null

    try {
        $bitmap = New-Object System.Drawing.Bitmap($ImagePath)
        $handle = $bitmap.GetHicon()
        $icon = [System.Drawing.Icon]::FromHandle($handle)
        return $icon.Clone()
    }
    finally {
        if ($null -ne $icon) {
            $icon.Dispose()
        }

        if ($handle -ne [IntPtr]::Zero) {
            [Kapsel.AssetNativeMethods]::DestroyIcon($handle) | Out-Null
        }

        if ($null -ne $bitmap) {
            $bitmap.Dispose()
        }
    }
}

Export-ModuleMember -Function @(
    'Get-KapselAssetsPath',
    'Get-KapselBrandImagePath',
    'New-KapselWindowIcon'
)

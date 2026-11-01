$ProjectRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
Import-Module (Join-Path $ProjectRoot 'src\modules\Domain\Diagnostics.psm1') -Force

Describe 'Diagnostic redaction' {
    It 'replaces profile paths and account names' {
        $text = "Path: $env:USERPROFILE\AppData\Local\Kapsel`nUser: $env:USERNAME"

        $redacted = Get-KapselRedactedText -Text $text

        $redacted | Should Match '%(USERPROFILE|LOCALAPPDATA)%'
        $redacted | Should Not Match ([regex]::Escape($env:USERPROFILE))
        $redacted | Should Not Match ([regex]::Escape($env:USERNAME))
    }

    It 'redacts profile paths from another account' {
        $redacted = Get-KapselRedactedText -Text 'C:\Users\someone.else\Documents\file.txt'

        $redacted | Should Be '%USERPROFILE%\Documents\file.txt'
    }

    It 'leaves ordinary diagnostic text unchanged' {
        $text = 'Kapsel 1.4.0 | winget available | 2 installed'

        Get-KapselRedactedText -Text $text | Should Be $text
    }

    It 'redacts a short account name only as a whole token' {
        $previous = $env:USERNAME
        try {
            $env:USERNAME = 'Admin'

            Get-KapselRedactedText -Text 'Administrator admin' | Should Be 'Administrator %USERNAME%'
        }
        finally {
            $env:USERNAME = $previous
        }
    }
}

$ProjectRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
Import-Module (Join-Path $ProjectRoot 'src\modules\Infrastructure\DiagnosticsAdapter.psm1') -Force

Describe 'Diagnostics adapter' {
    It 'writes a report atomically and returns the resolved path' {
        $root = Join-Path ([IO.Path]::GetTempPath()) ('kapsel-diagnostics-' + [Guid]::NewGuid().ToString('N'))
        try {
            $path = Join-Path $root 'reports\Kapsel-diagnostics.txt'
            $resolved = Write-KapselDiagnosticsFile -Path $path -Text "line one`nline two"

            $resolved | Should Be $path
            (Get-Content -LiteralPath $path -Raw).Trim() | Should Be "line one`nline two"
            @(Get-ChildItem -LiteralPath (Split-Path -Parent $path) -Filter '*.tmp').Count | Should Be 0
        }
        finally {
            if (Test-Path -LiteralPath $root) { Remove-Item -LiteralPath $root -Recurse -Force }
        }
    }

    It 'lists the newest package logs first' {
        $root = Join-Path ([IO.Path]::GetTempPath()) ('kapsel-logs-' + [Guid]::NewGuid().ToString('N'))
        try {
            [void] (New-Item -ItemType Directory -Path $root)
            $old = Join-Path $root 'old.stdout.log'
            $new = Join-Path $root 'new.stdout.log'
            [IO.File]::WriteAllText($old, 'old')
            Start-Sleep -Milliseconds 20
            [IO.File]::WriteAllText($new, 'new')

            $files = @(Get-KapselPackageLogFiles -Directory $root -Limit 5)

            $files.Count | Should Be 2
            $files[0].Name | Should Be 'new.stdout.log'
        }
        finally {
            if (Test-Path -LiteralPath $root) { Remove-Item -LiteralPath $root -Recurse -Force }
        }
    }

    It 'removes only logs older than the retention window' {
        $root = Join-Path ([IO.Path]::GetTempPath()) ('kapsel-retention-' + [Guid]::NewGuid().ToString('N'))
        try {
            [void] (New-Item -ItemType Directory -Path $root)
            $expired = Join-Path $root 'expired.stdout.log'
            $recent = Join-Path $root 'recent.stdout.log'
            [IO.File]::WriteAllText($expired, 'expired')
            [IO.File]::WriteAllText($recent, 'recent')
            [IO.File]::SetLastWriteTime($expired, (Get-Date).AddDays(-45))
            [IO.File]::SetLastWriteTime($recent, (Get-Date).AddDays(-2))

            $removed = Remove-KapselExpiredPackageLogs -Directory $root -RetentionDays 30

            $removed | Should Be 1
            Test-Path -LiteralPath $expired | Should Be $false
            Test-Path -LiteralPath $recent | Should Be $true
        }
        finally {
            if (Test-Path -LiteralPath $root) { Remove-Item -LiteralPath $root -Recurse -Force }
        }
    }
}

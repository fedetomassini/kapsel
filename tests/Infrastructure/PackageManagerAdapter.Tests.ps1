$ProjectRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
Import-Module (Join-Path $ProjectRoot 'src\modules\Infrastructure\PackageManagerAdapter.psm1') -Force

Describe 'Package process adapter' {
    It 'captures a real child process exit code and retains diagnostic output' {
        $result = Invoke-KapselPackageProcess -Command ([PSCustomObject] @{
            Executable = 'powershell.exe'
            Arguments = @('-NoProfile', '-Command', '"[Console]::Out.WriteLine(''test output''); [Console]::Error.WriteLine(''test error''); exit 7"')
        })
        $result.ExitCode | Should Be 7
        $result.Diagnostics | Should Match 'test output'
        $result.Diagnostics | Should Match 'test error'
        $result.Diagnostics | Should Not Match 'Logs:'
        $paths = $result.LogPaths
        (Get-Content -LiteralPath $paths[0] -Raw) | Should Match 'test output'
        (Get-Content -LiteralPath $paths[1] -Raw) | Should Match 'test error'
    }
}

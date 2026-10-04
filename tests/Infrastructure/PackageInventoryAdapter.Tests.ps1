$ProjectRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
Import-Module (Join-Path $ProjectRoot 'src\modules\Infrastructure\PackageInventoryAdapter.psm1') -Force

Describe 'Inventory subprocess lifecycle' {
    It 'captures both streams and the exit code of a harmless child process' {
        $code = "[Console]::Out.WriteLine('inventory output'); [Console]::Error.WriteLine('inventory error'); exit 7"
        $encoded = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($code))
        $result = Invoke-KapselInventoryProcess -Executable 'powershell.exe' -Arguments "-NoProfile -EncodedCommand $encoded"
        $result.ExitCode | Should Be 7
        $result.Output | Should Match 'inventory output'
        $result.Error | Should Match 'inventory error'
    }

    It 'terminates a blocked query at the timeout' {
        $watch = [Diagnostics.Stopwatch]::StartNew()
        { Invoke-KapselInventoryProcess -Executable 'powershell.exe' -Arguments '-NoProfile -Command "Start-Sleep -Seconds 20"' -TimeoutSeconds 1 } | Should Throw 'timed out'
        $watch.Elapsed.TotalSeconds | Should BeLessThan 5
    }

    It 'honors cancellation before starting a process and while a query is running' {
        $cancelled = New-Object Threading.CancellationTokenSource
        $active = New-Object Threading.CancellationTokenSource
        try {
            $cancelled.Cancel()
            { Invoke-KapselInventoryProcess -Executable 'not-a-real-executable' -Arguments '--version' -CancellationToken $cancelled.Token } | Should Throw 'cancelled'
            $active.CancelAfter(1000)
            $watch = [Diagnostics.Stopwatch]::StartNew()
            { Invoke-KapselInventoryProcess -Executable 'powershell.exe' -Arguments '-NoProfile -Command "Start-Sleep -Seconds 20"' -CancellationToken $active.Token } | Should Throw 'cancelled'
            $watch.Elapsed.TotalSeconds | Should BeLessThan 5
        }
        finally { $cancelled.Dispose(); $active.Dispose() }
    }
}

Describe 'Provider diagnostics' {
    BeforeEach {
        Mock Get-Command -ModuleName PackageInventoryAdapter { [PSCustomObject] @{ Path = 'fake-provider.exe' } }
        Mock Invoke-KapselInventoryProcess -ModuleName PackageInventoryAdapter {
            param($Arguments)
            [PSCustomObject] @{ ExitCode = 0; Output = $(if ($Arguments -eq '--version') { 'v1.12.0' } else { '--upgrade-available --disable-interactivity' }); Error = '' }
        }
    }

    It 'reports a missing executable without trying to invoke it' {
        Mock Get-Command -ModuleName PackageInventoryAdapter { $null }
        $result = Get-KapselProviderDiagnostics -Provider winget
        $result.Available | Should Be $false
        $result.Message | Should Match 'not found on PATH'
        Assert-MockCalled Invoke-KapselInventoryProcess -ModuleName PackageInventoryAdapter -Times 0 -Exactly
    }

    It 'reports the resolved path and version and checks invariant inventory flags' {
        $result = Get-KapselProviderDiagnostics -Provider winget
        $result.Version | Should Be '1.12.0'
        $result.ExecutablePath | Should Be 'fake-provider.exe'
        $result.Supported | Should Be $true
        Mock Invoke-KapselInventoryProcess -ModuleName PackageInventoryAdapter { [PSCustomObject] @{ ExitCode = 0; Output = 'v1.0.0'; Error = '' } }
        (Get-KapselProviderDiagnostics -Provider winget).Supported | Should Be $false
    }

    It 'does not mistake Chocolatey 1 remote list semantics for local inventory' {
        Mock Invoke-KapselInventoryProcess -ModuleName PackageInventoryAdapter { [PSCustomObject] @{ ExitCode = 0; Output = '1.4.0'; Error = '' } }
        $result = Get-KapselProviderDiagnostics -Provider choco
        $result.Supported | Should Be $false
        $result.Message | Should Match 'Chocolatey 2'
    }

    It 'explains failed version queries without hiding their original provider output' {
        Mock Invoke-KapselInventoryProcess -ModuleName PackageInventoryAdapter { [PSCustomObject] @{ ExitCode = 7; Output = 'provider detail'; Error = 'version failure' } }
        $result = Get-KapselProviderDiagnostics -Provider winget
        $result.Supported | Should Be $false
        $result.Message | Should Match 'exit 7'
        $result.Message | Should Match 'provider detail'
        $result.ExecutablePath | Should Be 'fake-provider.exe'
    }
}

Describe 'Provider inventory boundary' {
    BeforeEach {
        Mock Get-KapselProviderDiagnostics -ModuleName PackageInventoryAdapter {
            param($Provider)
            [PSCustomObject] @{ Provider = $Provider; Available = $true; Supported = $true; ExecutablePath = "$Provider.exe"; Version = '2.0.0'; Message = '' }
        }
    }

    It 'keeps installed Chocolatey data when the update query fails' {
        Mock Invoke-KapselInventoryProcess -ModuleName PackageInventoryAdapter {
            param($Arguments)
            if ($Arguments.StartsWith('list ')) { [PSCustomObject] @{ ExitCode = 0; Output = 'firefox|130.0'; Error = '' } }
            else { [PSCustomObject] @{ ExitCode = 7; Output = 'source detail'; Error = 'network failure' } }
        }
        $result = Get-KapselProviderInventory -Provider choco
        $result.InstalledOutput | Should Be 'firefox|130.0'
        $result.UpdatesChecked | Should Be $false
        $result.Warning | Should Match 'exit 7'
        $result.Warning | Should Match 'source detail'
    }

    It 'keeps installed data when an update query throws but propagates cancellation' {
        Mock Invoke-KapselInventoryProcess -ModuleName PackageInventoryAdapter {
            param($Arguments)
            if ($Arguments.StartsWith('list ')) { [PSCustomObject] @{ ExitCode = 0; Output = 'firefox|130.0'; Error = '' } }
            else { throw 'query timed out' }
        }
        (Get-KapselProviderInventory -Provider choco).Warning | Should Match 'timed out'
        $cancelled = New-Object Threading.CancellationTokenSource
        try {
            $cancelled.Cancel()
            { Get-KapselProviderInventory -Provider choco -CancellationToken $cancelled.Token } | Should Throw
        }
        finally { $cancelled.Dispose() }
    }

    It 'classifies winget source and permission failures by numeric exit code' {
        foreach ($case in @(
            @{ ExitCode = -1978335157; Expected = 'sources unavailable' },
            @{ ExitCode = -2147024891; Expected = 'Permission denied' }
        )) {
            & (Get-Module PackageInventoryAdapter) { param($code) $script:inventoryExitCode = $code } $case.ExitCode
            Mock Invoke-KapselInventoryProcess -ModuleName PackageInventoryAdapter { [PSCustomObject] @{ ExitCode = $script:inventoryExitCode; Output = 'localized provider detail'; Error = '' } }
            { Get-KapselProviderInventory -Provider winget } | Should Throw $case.Expected
        }
    }

    It 'reads winget export, treats no-updates as a successful check and removes its temporary file' {
        $script:exportPath = ''
        Mock Invoke-KapselInventoryProcess -ModuleName PackageInventoryAdapter {
            param($Arguments)
            if ($Arguments.StartsWith('export ')) {
                [void] ($Arguments -match '--output "([^"]+)"')
                $script:exportPath = $matches[1]
                [IO.File]::WriteAllText($script:exportPath, '{"Sources":[{"Packages":[{"PackageIdentifier":"Mozilla.Firefox","Version":"130.0"}]}]}')
                [PSCustomObject] @{ ExitCode = 0; Output = ''; Error = '' }
            }
            else { [PSCustomObject] @{ ExitCode = -1978335212; Output = ''; Error = '' } }
        }
        $result = Get-KapselProviderInventory -Provider winget
        $result.InstalledDocument.Sources[0].Packages[0].Version | Should Be '130.0'
        $result.UpdatesChecked | Should Be $true
        $result.Warning | Should BeNullOrEmpty
        $exportPath = & (Get-Module PackageInventoryAdapter) { $script:exportPath }
        Test-Path -LiteralPath $exportPath | Should Be $false
    }

    It 'explains invalid exported JSON and still cleans the temporary file' {
        $script:exportPath = ''
        Mock Invoke-KapselInventoryProcess -ModuleName PackageInventoryAdapter {
            param($Arguments)
            [void] ($Arguments -match '--output "([^"]+)"')
            $script:exportPath = $matches[1]
            [IO.File]::WriteAllText($script:exportPath, '{broken')
            [PSCustomObject] @{ ExitCode = 0; Output = ''; Error = '' }
        }
        { Get-KapselProviderInventory -Provider winget } | Should Throw 'could not be parsed'
        $exportPath = & (Get-Module PackageInventoryAdapter) { $script:exportPath }
        Test-Path -LiteralPath $exportPath | Should Be $false
    }

    It 'retains winget installed data after a failed update query and cleans the export' {
        Mock Invoke-KapselInventoryProcess -ModuleName PackageInventoryAdapter {
            param($Arguments)
            if ($Arguments.StartsWith('export ')) {
                [void] ($Arguments -match '--output "([^"]+)"')
                $script:exportPath = $matches[1]
                [IO.File]::WriteAllText($script:exportPath, '{"Sources":[{"Packages":[{"PackageIdentifier":"Mozilla.Firefox","Version":"130.0"}]}]}')
                [PSCustomObject] @{ ExitCode = 0; Output = ''; Error = '' }
            }
            else { [PSCustomObject] @{ ExitCode = -1978335157; Output = 'source detail'; Error = '' } }
        }
        $result = Get-KapselProviderInventory -Provider winget
        $result.InstalledDocument.Sources[0].Packages[0].Version | Should Be '130.0'
        $result.UpdatesChecked | Should Be $false
        $result.Warning | Should Match 'sources unavailable'
        $result.Warning | Should Match 'source detail'
        $exportPath = & (Get-Module PackageInventoryAdapter) { $script:exportPath }
        Test-Path -LiteralPath $exportPath | Should Be $false
    }
}

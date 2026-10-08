$ProjectRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
Import-Module (Join-Path $ProjectRoot 'src\modules\Presentation\WinForms\PackageOperationRunner.psm1') -Force

Describe 'Background package batch' {
    It 'cancels queued work without interrupting the active fake process' {
        $plan = [PSCustomObject] @{ Provider = 'winget'; Supported = @(
            [PSCustomObject] @{ Name = 'First'; WingetId = 'Vendor.First'; ChocoId = $null },
            [PSCustomObject] @{ Name = 'Second'; WingetId = 'Vendor.Second'; ChocoId = $null }
        ) }
        $source = New-Object System.Threading.CancellationTokenSource
        $batch = Start-KapselPackageBatch -Plan $plan -Action Install -ProviderStatus ([PSCustomObject] @{ WingetAvailable = $true }) -CancellationToken $source.Token -ProcessInvoker {
            param($Command)
            Start-Sleep -Seconds 1
            [PSCustomObject] @{ ExitCode = 0; Diagnostics = '' }
        }
        try {
            $deadline = [DateTime]::UtcNow.AddSeconds(5)
            while ($batch.Events.Count -eq 0 -and [DateTime]::UtcNow -lt $deadline) { Start-Sleep -Milliseconds 20 }
            $batch.Events.Count | Should Be 1
            $source.Cancel()
            $batch.Handle.AsyncWaitHandle.WaitOne(5000) | Should Be $true
            [void] $batch.Worker.EndInvoke($batch.Handle)
            $events = @($batch.Events.ToArray())
            ($events.Kind -join ',') | Should Be 'Started,Completed,Cancelled'
            $events[1].Result.Succeeded | Should Be $true
            $events[2].Application | Should Be 'Second'
        }
        finally { $batch.Worker.Dispose(); $source.Dispose() }
    }

    It 'starts no processes when cancellation was requested before scheduling' {
        $source = New-Object System.Threading.CancellationTokenSource
        $source.Cancel()
        $plan = [PSCustomObject] @{ Provider = 'winget'; Supported = @([PSCustomObject] @{ Name = 'Pending'; WingetId = 'Vendor.Pending'; ChocoId = $null }) }
        $batch = Start-KapselPackageBatch -Plan $plan -Action Install -ProviderStatus ([PSCustomObject] @{ WingetAvailable = $true }) -CancellationToken $source.Token -ProcessInvoker { throw 'Must never run' }
        try {
            $batch.Handle.AsyncWaitHandle.WaitOne(5000) | Should Be $true
            [void] $batch.Worker.EndInvoke($batch.Handle)
            $batch.Worker.Streams.Error.Count | Should Be 0
            (@($batch.Events.ToArray()).Kind -join ',') | Should Be 'Cancelled'
        }
        finally { $batch.Worker.Dispose(); $source.Dispose() }
    }
    foreach ($action in @('Install', 'Upgrade')) {
        It "reports ordered progress and continues after process failures for $action" {
            $plan = [PSCustomObject] @{
                Provider = 'winget'
                Supported = @(
                    [PSCustomObject] @{ Name = 'Good'; WingetId = 'Vendor.Good'; ChocoId = $null },
                    [PSCustomObject] @{ Name = 'Bad'; WingetId = 'Vendor.Bad'; ChocoId = $null },
                    [PSCustomObject] @{ Name = 'Throws'; WingetId = 'Vendor.Throws'; ChocoId = $null },
                    [PSCustomObject] @{ Name = 'Last'; WingetId = 'Vendor.Last'; ChocoId = $null }
                )
            }
            $invoker = {
                param($Command)
                Start-Sleep -Milliseconds 100
                if ($Command.Display -match 'Vendor.Throws') { throw 'Simulated launch failure' }
                $code = if ($Command.Display -match 'Vendor.Bad') { 7 } else { 0 }
                [PSCustomObject] @{ ExitCode = $code; Diagnostics = 'Test log' }
            }
            $batch = Start-KapselPackageBatch -Plan $plan -Action $action -ProviderStatus ([PSCustomObject] @{ WingetAvailable = $true }) -ProcessInvoker $invoker
            try {
                $batch.Handle.IsCompleted | Should Be $false
                $batch.Handle.AsyncWaitHandle.WaitOne(10000) | Should Be $true
                [void] $batch.Worker.EndInvoke($batch.Handle)
                $batch.Worker.Streams.Error.Count | Should Be 0
                $events = @($batch.Events.ToArray())
                $events.Count | Should Be 8
                ($events.Kind -join ',') | Should Be 'Started,Completed,Started,Completed,Started,Failed,Started,Completed'
                $events[1].Result.Succeeded | Should Be $true
                $events[1].Result.Action | Should Be $action
                $events[3].Result.Succeeded | Should Be $false
                $events[3].Result.Diagnostics | Should Be 'Test log'
                $events[5].Message | Should Match 'Simulated launch failure'
                $events[7].Result.Succeeded | Should Be $true
            }
            finally { $batch.Worker.Dispose() }
        }
    }
}

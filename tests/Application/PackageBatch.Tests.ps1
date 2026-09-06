$ProjectRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
Import-Module (Join-Path $ProjectRoot 'src\modules\Presentation\WinForms\PackageOperationRunner.psm1') -Force

Describe 'Background package batch' {
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

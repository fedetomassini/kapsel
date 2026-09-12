$ProjectRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
Import-Module (Join-Path $ProjectRoot 'src\modules\Presentation\WinForms\InventoryRunner.psm1') -Force

Describe 'Background inventory scan' {
    It 'returns a mapped snapshot without invoking a real provider' {
        $applications = @([PSCustomObject] @{ Key = 'firefox'; WingetId = 'Mozilla.Firefox'; ChocoId = 'firefox' })
        $scan = Start-KapselInventoryScan -Applications $applications -Provider choco -ProviderInvoker {
            param($SelectedProvider, $Token)
            return [PSCustomObject] @{
                InstalledOutput = 'firefox|130.0'
                UpdateOutput = 'firefox|130.0|131.0|false'
                UpdatesChecked = $true
                Warning = ''
            }
        }
        try {
            $scan.Handle.AsyncWaitHandle.WaitOne(5000) | Should Be $true
            $result = @($scan.Worker.EndInvoke($scan.Handle)) | Select-Object -First 1
            $result.Snapshot.States.firefox.Status | Should Be 'UpdateAvailable'
        }
        finally {
            $scan.Worker.Dispose()
            $scan.Cancellation.Dispose()
        }
    }
}

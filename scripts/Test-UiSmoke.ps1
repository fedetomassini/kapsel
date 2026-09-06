# Opens the real launcher, verifies that WinForms creates a window, and closes it.
[CmdletBinding()]
param(
    [int] $TimeoutSeconds = 10,
    [string] $ScreenshotPath,
    [string] $LauncherPath,
    [switch] $ExercisePackageActions
)

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
if ($ExercisePackageActions) {
    # Always use the fixture when accepting install/update confirmations.
    $LauncherPath = Join-Path $projectRoot 'tests\Fixtures\PackageUi.ps1'
}
$resolvedLauncherPath = if ([string]::IsNullOrWhiteSpace($LauncherPath)) {
    Join-Path $projectRoot 'kapsel.ps1'
}
elseif ([System.IO.Path]::IsPathRooted($LauncherPath)) {
    $LauncherPath
}
else {
    Join-Path $projectRoot $LauncherPath
}
if (-not (Test-Path -LiteralPath $resolvedLauncherPath -PathType Leaf)) {
    throw "Kapsel launcher was not found: $resolvedLauncherPath"
}
$process = $null

try {
    $launcherDirectory = Split-Path -Parent $resolvedLauncherPath
    if ([System.IO.Path]::GetExtension($resolvedLauncherPath) -ieq '.exe') {
        $process = Start-Process -FilePath $resolvedLauncherPath -WorkingDirectory $launcherDirectory -PassThru
    }
    else {
        $process = Start-Process -FilePath 'powershell.exe' -ArgumentList @(
            '-NoProfile',
            '-STA',
            '-ExecutionPolicy', 'Bypass',
            '-File', ('"{0}"' -f $resolvedLauncherPath)
        ) -WorkingDirectory $launcherDirectory -PassThru
    }

    $deadline = [DateTime]::UtcNow.AddSeconds($TimeoutSeconds)
    do {
        Start-Sleep -Milliseconds 250
        $process.Refresh()
        if ($process.HasExited) {
            throw "Kapsel exited before creating its window. Exit code: $($process.ExitCode)"
        }
    } while ($process.MainWindowHandle -eq [IntPtr]::Zero -and [DateTime]::UtcNow -lt $deadline)

    if ($process.MainWindowHandle -eq [IntPtr]::Zero) {
        throw "Kapsel did not create a window within $TimeoutSeconds seconds."
    }
    if ($process.MainWindowTitle -ne 'Kapsel') {
        throw "Unexpected Kapsel window title: '$($process.MainWindowTitle)'"
    }

    Write-Host "Kapsel window detected: $($process.MainWindowHandle)"

    Add-Type -AssemblyName UIAutomationClient
    Add-Type -AssemblyName UIAutomationTypes
    if (-not ('KapselSmoke.NativeMethods' -as [type])) {
        Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;

namespace KapselSmoke {
    [StructLayout(LayoutKind.Sequential)]
    public struct Rect {
        public int Left;
        public int Top;
        public int Right;
        public int Bottom;
    }

    public static class NativeMethods {
        [DllImport("user32.dll", CharSet = CharSet.Unicode, EntryPoint = "SendMessageW")]
        public static extern IntPtr SetText(IntPtr hWnd, uint msg, IntPtr wParam, string lParam);

        [DllImport("user32.dll", EntryPoint = "SendMessageW")]
        public static extern IntPtr SendMessage(IntPtr hWnd, uint msg, IntPtr wParam, IntPtr lParam);

        [DllImport("user32.dll")]
        public static extern bool PostMessage(IntPtr hWnd, uint msg, IntPtr wParam, IntPtr lParam);

        [DllImport("user32.dll")]
        public static extern bool GetWindowRect(IntPtr hWnd, out Rect rect);
    }
}
"@
    }
    $processCondition = New-Object System.Windows.Automation.PropertyCondition(
        [System.Windows.Automation.AutomationElement]::ProcessIdProperty,
        $process.Id
    )
    $window = [System.Windows.Automation.AutomationElement]::RootElement.FindFirst(
        [System.Windows.Automation.TreeScope]::Children,
        $processCondition
    )
    if ($null -eq $window) {
        throw 'Kapsel window was not available through Windows UI Automation.'
    }

    $controls = $window.FindAll(
        [System.Windows.Automation.TreeScope]::Descendants,
        [System.Windows.Automation.Condition]::TrueCondition
    )
    $chromeControls = @{
        KapselMinimizeButton = [string][char] 0xE921
        KapselMaximizeButton = [string][char] 0xE922
        KapselCloseButton    = [string][char] 0xE8BB
    }
    foreach ($automationId in $chromeControls.Keys) {
        $chromeControl = $controls |
            Where-Object {
                $_.Current.AutomationId -eq $automationId -or
                ($_.Current.ClassName -like '*.BUTTON.*' -and $_.Current.Name -eq $chromeControls[$automationId])
            } |
            Select-Object -First 1
        if ($null -eq $chromeControl) {
            throw "Custom window control was not found: $automationId"
        }
    }

    $packageVersion = (Get-Content -LiteralPath (Join-Path $projectRoot 'package.json') -Raw | ConvertFrom-Json).version
    foreach ($section in @(
        [PSCustomObject] @{ Button = 'Features'; Expected = 'CATALOG' },
        [PSCustomObject] @{ Button = 'Changes'; Expected = "VERSION $packageVersion" },
        [PSCustomObject] @{ Button = 'Activity'; Expected = $null }
    )) {
        $sectionButton = $controls |
            Where-Object { $_.Current.ClassName -like '*.BUTTON.*' -and $_.Current.Name -eq $section.Button } |
            Select-Object -First 1
        if ($null -eq $sectionButton) { throw "Context section button was not found: $($section.Button)" }
        [KapselSmoke.NativeMethods]::SendMessage([IntPtr] $sectionButton.Current.NativeWindowHandle, 0x00F5, [IntPtr]::Zero, [IntPtr]::Zero) | Out-Null
        Start-Sleep -Milliseconds 100
        $controls = $window.FindAll(
            [System.Windows.Automation.TreeScope]::Descendants,
            [System.Windows.Automation.Condition]::TrueCondition
        )
        if ($null -ne $section.Expected) {
            $visibleContent = $controls |
                Where-Object { $_.Current.Name -eq $section.Expected -and -not $_.Current.IsOffscreen } |
                Select-Object -First 1
            if ($null -eq $visibleContent) {
                throw "Context section did not display its expected content: $($section.Button)"
            }
        }
    }

    $searchBox = $controls |
        Where-Object { $_.Current.ClassName -like '*.EDIT.*' } |
        Select-Object -First 1
    if ($null -eq $searchBox) { throw 'Kapsel search control was not found.' }
    [KapselSmoke.NativeMethods]::SetText([IntPtr] $searchBox.Current.NativeWindowHandle, 0x000C, [IntPtr]::Zero, 'Mozilla.Firefox') | Out-Null

    $providerButton = $controls |
        Where-Object { $_.Current.ClassName -like '*.BUTTON.*' -and $_.Current.Name -eq 'winget' } |
        Select-Object -First 1
    if ($null -ne $providerButton -and $providerButton.Current.IsEnabled) {
        [KapselSmoke.NativeMethods]::SendMessage([IntPtr] $providerButton.Current.NativeWindowHandle, 0x00F5, [IntPtr]::Zero, [IntPtr]::Zero) | Out-Null
    }

    Start-Sleep -Milliseconds 500
    $process.Refresh()
    if ($process.HasExited) {
        throw "Kapsel exited while exercising search and provider controls. Exit code: $($process.ExitCode)"
    }
    if ($ExercisePackageActions) {
        $selectButton = $controls | Where-Object { $_.Current.Name -eq 'Select visible' } | Select-Object -First 1
        [KapselSmoke.NativeMethods]::SendMessage([IntPtr] $selectButton.Current.NativeWindowHandle, 0x00F5, [IntPtr]::Zero, [IntPtr]::Zero) | Out-Null
        foreach ($action in @(
            @{ Button = 'Install'; Verb = 'Install'; Summary = '2 succeeded, 0 failed' },
            @{ Button = 'Update'; Verb = 'Upgrade'; Summary = '0 completed, 1 unchanged, 1 failed' },
            @{ Button = 'Update'; Verb = 'Upgrade'; Summary = '0 completed, 2 unchanged, 0 failed' }
        )) {
            $button = $controls | Where-Object { $_.Current.Name -eq $action.Button } | Select-Object -First 1
            if (-not $button.Current.IsEnabled) { throw "Action disabled before confirmation: $($action.Button)" }
            [KapselSmoke.NativeMethods]::PostMessage([IntPtr] $button.Current.NativeWindowHandle, 0x00F5, [IntPtr]::Zero, [IntPtr]::Zero) | Out-Null
            $deadline = [DateTime]::UtcNow.AddSeconds(5)
            $dialog = $null
            do {
                Start-Sleep -Milliseconds 100
                $dialog = [System.Windows.Automation.AutomationElement]::RootElement.FindAll(
                    [System.Windows.Automation.TreeScope]::Descendants, $processCondition
                ) | Where-Object { $_.Current.Name -eq 'Confirm package action' } | Select-Object -First 1
            } while ($null -eq $dialog -and [DateTime]::UtcNow -lt $deadline)
            if ($null -eq $dialog) {
                $details = [System.Windows.Automation.AutomationElement]::RootElement.FindAll([System.Windows.Automation.TreeScope]::Descendants, $processCondition) | ForEach-Object { $_.Current.Name }
                throw "Missing confirmation for $($action.Button). Controls: $($details -join ' | ')"
            }
            $dialogControls = $dialog.FindAll([System.Windows.Automation.TreeScope]::Descendants, [System.Windows.Automation.Condition]::TrueCondition)
            if (-not ($dialogControls | Where-Object { $_.Current.Name -like '*with winget?*' })) { throw 'Provider confirmation text is missing.' }
            $yes = $dialogControls | Where-Object { $_.Current.AutomationId -eq '6' } | Select-Object -First 1
            if ($null -eq $yes) { throw 'Confirmation Yes button missing.' }
            [KapselSmoke.NativeMethods]::PostMessage([IntPtr] $yes.Current.NativeWindowHandle, 0x00F5, [IntPtr]::Zero, [IntPtr]::Zero) | Out-Null
            Start-Sleep -Milliseconds 500
            if ($button.Current.IsEnabled) { throw 'Package action remained enabled during execution.' }
            $runningControls = $window.FindAll([System.Windows.Automation.TreeScope]::Descendants, [System.Windows.Automation.Condition]::TrueCondition)
            if (-not ($runningControls | Where-Object { $_.Current.Name -like '*0/2 completed*' })) { throw 'Running package progress is missing.' }
            # Search must still respond while the background adapter is waiting.
            [KapselSmoke.NativeMethods]::SetText([IntPtr] $searchBox.Current.NativeWindowHandle, 0x000C, [IntPtr]::Zero, 'Mozilla.Firefox') | Out-Null
            $expected = "$($action.Verb) finished: $($action.Summary)"
            $deadline = [DateTime]::UtcNow.AddSeconds(10)
            do {
                Start-Sleep -Milliseconds 100
                $currentControls = $window.FindAll([System.Windows.Automation.TreeScope]::Descendants, [System.Windows.Automation.Condition]::TrueCondition)
                $summary = $currentControls | Where-Object { $_.Current.Name -eq $expected } | Select-Object -First 1
            } while ($null -eq $summary -and [DateTime]::UtcNow -lt $deadline)
            if ($null -eq $summary) { throw "Missing package result: $expected" }
            if ($action.Button -eq 'Update') {
                if (-not ($currentControls | Where-Object { $_.Current.Name -like '*No newer version is available*' })) { throw 'Activity did not explain the unchanged application.' }
                if (-not ($currentControls | Where-Object { $_.Current.Name -like '*Simulated provider failure*' })) { throw 'Provider failure details are missing from Activity.' }
            }
            if (-not $button.Current.IsEnabled) { throw 'Package actions were not restored.' }
            Write-Host "Verified package UI: $expected"
        }
    }
    [KapselSmoke.NativeMethods]::SetText([IntPtr] $searchBox.Current.NativeWindowHandle, 0x000C, [IntPtr]::Zero, '') | Out-Null

    $maximizeButton = $controls |
        Where-Object {
            $_.Current.AutomationId -eq 'KapselMaximizeButton' -or
            ($_.Current.ClassName -like '*.BUTTON.*' -and $_.Current.Name -eq ([string][char] 0xE922))
        } |
        Select-Object -First 1
    [KapselSmoke.NativeMethods]::SendMessage([IntPtr] $maximizeButton.Current.NativeWindowHandle, 0x00F5, [IntPtr]::Zero, [IntPtr]::Zero) | Out-Null
    Start-Sleep -Milliseconds 300

    $window = [System.Windows.Automation.AutomationElement]::RootElement.FindFirst(
        [System.Windows.Automation.TreeScope]::Children,
        $processCondition
    )
    $controls = $window.FindAll(
        [System.Windows.Automation.TreeScope]::Descendants,
        [System.Windows.Automation.Condition]::TrueCondition
    )
    $restoreButton = $controls |
        Where-Object { $_.Current.ClassName -like '*.BUTTON.*' -and $_.Current.Name -eq ([string][char] 0xE923) } |
        Select-Object -First 1
    if ($null -eq $restoreButton) { throw 'Custom window did not enter the maximized state.' }
    [KapselSmoke.NativeMethods]::SendMessage([IntPtr] $restoreButton.Current.NativeWindowHandle, 0x00F5, [IntPtr]::Zero, [IntPtr]::Zero) | Out-Null
    Start-Sleep -Milliseconds 300

    $window = [System.Windows.Automation.AutomationElement]::RootElement.FindFirst(
        [System.Windows.Automation.TreeScope]::Children,
        $processCondition
    )
    $controls = $window.FindAll(
        [System.Windows.Automation.TreeScope]::Descendants,
        [System.Windows.Automation.Condition]::TrueCondition
    )

    if (-not [string]::IsNullOrWhiteSpace($ScreenshotPath)) {
        Add-Type -AssemblyName System.Drawing
        $resolvedScreenshotPath = if ([System.IO.Path]::IsPathRooted($ScreenshotPath)) {
            $ScreenshotPath
        }
        else {
            Join-Path $projectRoot $ScreenshotPath
        }
        $screenshotDirectory = Split-Path -Parent $resolvedScreenshotPath
        if (-not (Test-Path -LiteralPath $screenshotDirectory)) {
            New-Item -ItemType Directory -Path $screenshotDirectory -Force | Out-Null
        }

        $rect = New-Object KapselSmoke.Rect
        if (-not [KapselSmoke.NativeMethods]::GetWindowRect($process.MainWindowHandle, [ref] $rect)) {
            throw 'Kapsel window bounds could not be read.'
        }
        $width = $rect.Right - $rect.Left
        $height = $rect.Bottom - $rect.Top
        $bitmap = New-Object System.Drawing.Bitmap($width, $height)
        $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
        try {
            $graphics.CopyFromScreen($rect.Left, $rect.Top, 0, 0, (New-Object System.Drawing.Size($width, $height)))
            $bitmap.Save($resolvedScreenshotPath, [System.Drawing.Imaging.ImageFormat]::Png)
        }
        finally {
            $graphics.Dispose()
            $bitmap.Dispose()
        }
        Write-Host "Screenshot: $resolvedScreenshotPath"
    }

    $closeButton = $controls |
        Where-Object {
            $_.Current.AutomationId -eq 'KapselCloseButton' -or
            ($_.Current.ClassName -like '*.BUTTON.*' -and $_.Current.Name -eq ([string][char] 0xE8BB))
        } |
        Select-Object -First 1
    [KapselSmoke.NativeMethods]::SendMessage([IntPtr] $closeButton.Current.NativeWindowHandle, 0x00F5, [IntPtr]::Zero, [IntPtr]::Zero) | Out-Null
    if (-not $process.WaitForExit(5000)) {
        throw 'Kapsel did not close after clicking Close.'
    }
    if ($process.ExitCode -ne 0) { throw "Kapsel exited with code $($process.ExitCode)." }
    Write-Host 'Kapsel UI smoke test passed.'
}
finally {
    if ($null -ne $process) {
        $process.Refresh()
        if (-not $process.HasExited) {
            $process.Kill()
            $process.WaitForExit()
        }
        $process.Dispose()
    }
}

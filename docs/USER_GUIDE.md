# User Guide

## Start Kapsel

Extract the **whole release ZIP** to a stable folder and open `kapsel.cmd`. Keep `src` and `assets`
beside the launcher. From Windows PowerShell, run `.\kapsel.ps1`. Node.js is not required.

For a launcher on your user PATH, run `.\install.ps1 -AddToUserPath` from that folder, then open
a new terminal and run `kapsel`. This creates wrappers pointing at the original app directory;
keep that directory in place. See [Configuration](CONFIGURATION.md) before moving it.

## Find and Select Applications

1. Choose **winget** or **Chocolatey** in the left panel. A provider must be available on PATH.
2. Use a category, the search field, and the FOSS filter to narrow the catalog.
3. Select individual rows or **Select visible**. Searches match names, keys, categories,
   descriptions and package IDs literally, ignoring case.
4. Selections survive search and category changes. Review the confirmation before running a batch,
   because selected apps can be outside the current view.
5. Mark favorites and use **Favorites** to return to them later. Favorites persist per user.

Use `Ctrl+F` to focus search and `Escape` to clear a non-empty search. The official-website action
opens the focused application's catalog link in your browser; it does not install that application.

## Understand Inventory

Inventory is queried in the background on startup, provider change, **Refresh**, and after a batch.
Use **All**, **Installed**, and **Updates** to filter the catalog. Counts describe matching catalog
apps for the active provider, not all software installed on Windows.

| State | Meaning |
| --- | --- |
| Unsupported | The catalog has no ID for the selected provider |
| Not detected | The provider did not match this app; it may still be installed |
| Installed | The provider matched an installed version |
| Update available | The provider reported an update for the matched package |
| Update check unavailable | Installed results may be valid, but update lookup failed |
| Inventory unavailable | The scan failed; inspect Activity and refresh after correcting the cause |

winget export cannot identify every application. A missing match is not proof of absence.
Provider source availability and output format affect the scan.

## Install or Update

1. Select apps and choose **Install** or **Update**.
2. Review the provider, action and supported selection in the confirmation dialog.
3. Confirm to start a serial batch. Unsupported selections are skipped and reported.
4. Watch **Activity** for the current package, elapsed time and completed-app progress.
5. Review the final result and any provider details. Inventory refreshes after the batch.

The progress bar counts finished apps, including failures, not downloaded bytes. You can search,
move and minimize the window while a package runs. A second batch and window closing are blocked
until completion. There is currently no package cancel action or execution timeout.

Some packages need administrator rights. Kapsel does not automatically elevate itself. Inspect the
provider error and use the publisher/provider's documented privilege requirements rather than
assuming every failure is a permissions problem.

## Interpret Results

- **Completed:** the provider returned success; review its output for specific details.
- **Unchanged:** no newer version or no installation needed; this is not a failed package.
- **Restart required:** Chocolatey returned a recognized restart code; follow the Activity message.
- **Failed:** inspect the exit code and provider output. Other apps in the batch can still succeed.

Chocolatey's no-update code depends on enhanced exit codes. A normal success message alone does
not prove a newer version was installed. Kapsel does not roll back a partially completed batch.

Activity is session-local. Provider stdout/stderr backup files are under
`%LOCALAPPDATA%\Kapsel\Logs`. Favorites are under `%LOCALAPPDATA%\Kapsel\preferences.json` by default.
See [Configuration](CONFIGURATION.md) for the preference override and
[Troubleshooting](TROUBLESHOOTING.md) for recovery steps.

## Upgrade Kapsel

Extract a newer release into a new folder and start its launcher. User favorites live outside the
release and remain available. If you installed PATH wrappers, rerun `install.ps1` from the new
location to point them at it. There is no built-in self-update or app-uninstall action.

Configuration flags do not enable features that have not been implemented.

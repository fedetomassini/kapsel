# Configuration and User Data

## Runtime and Launchers

Kapsel uses Windows PowerShell 5.1 and Windows Forms on Windows 10/11. Root CMD and npm launchers
request STA and a **process-scoped** execution-policy bypass. They do not change the machine's
execution policy or override enterprise controls. Optional EXE builds also require adjacent `src`
and `assets` directories.

Provider executables are discovered through `Get-Command` on the app process's PATH. Provider
configuration, sources, credentials, proxy settings and elevation behavior belong to winget or
Chocolatey; Kapsel does not offer a separate source-management configuration file.

## User Files

| Data | Default location | Lifecycle |
| --- | --- | --- |
| Favorites | `%LOCALAPPDATA%\Kapsel\preferences.json` | Read on startup, written on favorite changes |
| Provider output | `%LOCALAPPDATA%\Kapsel\Logs\*.stdout.log` and `*.stderr.log` | Written per package process; no automatic retention limit |
| Inventory export | System temporary directory, `kapsel-inventory-<guid>.json` | Removed after a winget scan |
| Activity and inventory | App memory | Reset on restart |
| Release build output | Repository `dist/releases` | Recreated by builds; ignored by Git |

Closing Kapsel before copying user files avoids capturing a write in progress. To back up favorites,
copy `preferences.json`; to restore, close the app and restore that file. Stable catalog keys map
favorites; keys absent from a non-empty catalog are ignored during normalization.

Current preference shape:

```json
{
  "SchemaVersion": 1,
  "FavoriteKeys": ["sevenzip"]
}
```

The writer always emits schema version 1. The reader does not currently reject future schema
versions. Do not edit a future-version file with an older app; explicit migration protection is
not currently implemented.

## Environment Variables

| Variable | Scope | Meaning |
| --- | --- | --- |
| `KAPSEL_DATA_DIRECTORY` | Preference repository | Non-empty value replaces the preference directory only |
| `PATH` | Provider discovery and launchers | Must contain the executable selected by Kapsel |
| `LOCALAPPDATA` / Windows special folder | Default user storage | Resolved through .NET's LocalApplicationData special folder |

Use an absolute writable local directory for an isolated development profile:

```powershell
$env:KAPSEL_DATA_DIRECTORY = Join-Path $env:TEMP 'kapsel-dev-profile'
npm run dev
Remove-Item Env:\KAPSEL_DATA_DIRECTORY
```

This does not isolate provider logs, actual installed software or provider settings. There are no
hidden flags enabling planned profiles, automatic updates, remote catalogs or cancellation.

## Installing PATH Wrappers

```powershell
.\install.ps1 -InstallDirectory "$env:USERPROFILE\Tools\Kapsel" -AddToUserPath
```

The wrappers point to the absolute `src/Kapsel.ps1` in the folder from which the installer was run.
Keep that source/release folder available. After moving/upgrading it, rerun installation from the
new location. Start a new terminal to pick up the modified user PATH.

There is no dedicated uninstall script. To remove PATH wrappers, identify the directory you used,
remove only its `kapsel.ps1`/`kapsel.cmd` wrappers, and remove its user PATH entry if no other tools
need it. Keep or remove the extracted app folder separately. User favorites/logs are not removed
automatically. Do not remove a shared tools directory or modify the machine PATH unnecessarily.

## Fonts and Assets

JetBrains Mono is preferred when installed; Segoe UI is the fallback. No font download occurs on
startup. See [Troubleshooting](TROUBLESHOOTING.md).

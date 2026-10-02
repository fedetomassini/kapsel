# Troubleshooting

## Kapsel Does Not Open

1. Extract the complete archive; confirm the launcher is beside `src` and `assets`.
2. Run `kapsel.cmd` or `.\kapsel.ps1` from Windows PowerShell to retain startup errors.
3. Check that `powershell.exe` is available and the session is not replacing it with `pwsh`.
4. Use the root/npm launcher so WinForms starts in STA.
5. If a managed Windows policy blocks scripts, follow your organization's approved process. The
   launcher only applies a process-level bypass and does not override organizational policy.

Opening a `.ps1` in an editor is a Windows file-association behavior; use the CMD launcher instead.

## Provider Is Unavailable

```powershell
Get-Command winget -ErrorAction SilentlyContinue
Get-Command choco -ErrorAction SilentlyContinue
```

Install or repair providers using their official instructions. Open a new terminal/app after PATH
changes. A missing catalog identifier means an app is unsupported by that provider even when the
provider itself is installed. Switching providers is not an automatic fallback for a failed batch.

## Installed App Is Not Detected

Inventory only matches provider-known catalog IDs. winget export can omit software installed outside
its recognizable sources, different editions/channels, or packages with incomplete metadata.
Use **Refresh**, verify the selected provider and compare the exact package ID. Do not interpret
**Not detected** as proof that the application is absent.

## Inventory or Update Check Fails

Inspect Activity. Try the corresponding **read-only** command from a terminal to distinguish source,
network, provider-version and parsing problems:

```powershell
winget list --upgrade-available --accept-source-agreements --disable-interactivity
choco list --limit-output --no-color
choco outdated --limit-output --no-color
```

Only run commands for the provider you use. Inventory subprocesses have a 90-second default timeout.
An update-query failure can retain installed state and show **update check unavailable**. A failed
installed query makes the whole inventory unavailable. Report output-format issues with provider
version and a sanitized relevant excerpt.

## Install or Update Fails

Read the app-specific Activity result and stdout/stderr logs in `%LOCALAPPDATA%\Kapsel\Logs`.
Common causes include source/network failure, permissions, installer conflicts and stale package IDs.
Keep the original exit code and package identifier when reporting the problem.

Some installers need administrator privileges. Determine the provider/package requirement first;
Kapsel does not auto-elevate. Successful no-update/already-installed results are unchanged outcomes,
not failures. A completed batch can contain both successes and failures and has no automatic rollback.

## A Package Appears Stuck

The progress bar counts finished applications, so it can stay still while one installer runs.
Elapsed time and the active-operation indicator continue. Current package execution has no timeout
or cancellation action; closing the window is blocked during a batch.

Check provider/installer activity and its logs before interrupting it. Force-terminating Kapsel is
not a rollback and may leave a child installer running or a package partially applied. After the
provider has completed or been recovered using its documented procedure, refresh inventory and
inspect the installed state before retrying.

## Favorites Do Not Persist

Check `%LOCALAPPDATA%\Kapsel\preferences.json`, or the preference directory set through
`KAPSEL_DATA_DIRECTORY`. Ensure it is writable and inspect Activity for read/write errors. The
override affects preferences only, not logs.

For malformed JSON, close Kapsel and **back up the file first**. Move it aside to let Kapsel start
with empty favorites, then restore known keys from the backup if appropriate. Do not overwrite a
file from a newer schema with an older app. Explicit version/recovery handling is planned, not
currently guaranteed. See [Configuration](CONFIGURATION.md).

## Installed PATH Launcher Breaks After a Move

`install.ps1` writes wrappers pointing to the original source directory. Run it again from the new
release location, or restore the previous folder. It does not copy/install the full app into the
wrapper directory. See [Configuration](CONFIGURATION.md#installing-path-wrappers).

## Tests or Builds Fail

- Pester version error: install/import 4.10.1 in Windows PowerShell, as in [Development](DEVELOPMENT.md).
- Generated catalog outdated: run `npm run docs:catalog` and review/commit root `CATALOG.md`.
- Local documentation link error: fix the reported path/heading, then run `npm run docs:check`.
- Optional executable error: `npm run build:exe` needs ps2exe; default builds do not.
- UI smoke failure: ensure an unlocked interactive desktop and no concurrent smoke run. Ordinary
  inventory smoke depends on provider/source availability; the package fixture is deterministic.

If the problem remains, use [SUPPORT.md](../SUPPORT.md) to file an actionable report.

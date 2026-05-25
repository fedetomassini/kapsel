# Installation

Kapsel 1.0.0 by Federico Tomassini.

## Run without installing

From the project root:

```powershell
.\kapsel.ps1
```

This is the recommended mode while developing.

On Windows, double-clicking a `.ps1` file can open it in an editor instead of running it. Use the terminal or the root `kapsel.cmd` launcher:

```cmd
kapsel.cmd
```

## Install for the current user

```powershell
.\install.ps1 -AddToUserPath
```

The installer creates:

- `kapsel.ps1`: PowerShell launcher.
- `kapsel.cmd`: command launcher so `kapsel` works from a new terminal.

It installs into `$HOME\bin` by default. Use `-InstallDirectory` to choose another path.

## Execution policy

If PowerShell blocks script execution, run from a trusted terminal:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\kapsel.ps1 help
```

Use execution policy changes only when you understand the impact on your user profile.


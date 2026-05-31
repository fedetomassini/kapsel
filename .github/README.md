# Kapsel

Kapsel is a Windows Forms application written in PowerShell for installing and updating applications from a local catalog: `src/applications.json`.

- Version: `1.0.0`
- Creator: Federico Tomassini

The name comes from `capsule`/`kapsel`: a compact container for a curated set of applications that can be installed or updated from one interface.

The app uses `winget` as the primary provider and Chocolatey as an optional fallback when the catalog defines a compatible package.

## Requirements

- Windows 10/11.
- PowerShell 5.1 or higher.
- `winget` recommended.
- Chocolatey optional.
- Pester optional for tests.

## Usage

From the project root:

```powershell
.\kapsel.ps1
```

From `cmd.exe` or Explorer:

```cmd
kapsel.cmd
```

The interface supports:

- searching applications by name, id, or description
- browsing applications by category
- filtering FOSS applications
- selecting multiple applications
- installing selected applications
- updating selected applications
- opening the official website for the selected application
- reviewing built-in Features and Changelog tabs

## Catalog

The catalog lives at:

```txt
src/applications.json
```

Each entry can define:

```json
{
  "category": "Utilities",
  "content": "7-Zip",
  "description": "File archiver",
  "link": "https://www.7-zip.org/",
  "winget": "7zip.7zip",
  "choco": "7zip",
  "foss": true
}
```

`winget` is preferred when available. If an entry has no `winget` value, the UI can use Chocolatey when `choco` is defined.

## What Is FOSS

FOSS means `Free and Open Source Software`. In practice, these are applications whose source code is publicly available and can usually be studied, modified, and redistributed under their license.

The `FOSS` filter in the interface shows only catalog entries marked with:

```json
"foss": true
```

## Architecture

```txt
src/
  applications.json
  Kapsel.ps1
  modules/
    Applications.psm1
    ApplicationGrid.psm1
    ApplicationInfo.psm1
    ApplicationMain.psm1
    ApplicationSidebar.psm1
    Branding.psm1
    Gui.psm1
    UiTheme.psm1
tests/
  Applications.Tests.ps1
```

- `Applications.psm1` reads and filters the catalog, detects package managers, and builds commands for `winget`/Chocolatey.
- `ApplicationSidebar.psm1`, `ApplicationMain.psm1`, and `ApplicationGrid.psm1` build independent UI sections.
- `UiTheme.psm1` centralizes colors, fonts, and shared controls.
- `Branding.psm1` centralizes the name, version, and creator.
- `Gui.psm1` composes the modules and wires events.
- `Kapsel.ps1` is the entry point.

## Tests

```powershell
Invoke-Pester .\tests
```

Tests validate the catalog and package-manager argument generation. They do not install or update applications.

## Security

- Installing and updating requires explicit confirmation in the UI.
- Kapsel does not download binaries directly.
- Operations are delegated to `winget` or Chocolatey.
- The catalog is local and maintainable by hand.



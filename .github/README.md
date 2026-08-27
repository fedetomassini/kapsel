# Kapsel

<p align="center">
  <img src="assets/kapsel.png" alt="Kapsel application catalog" width="860">
</p>

Kapsel is a native Windows application for installing and updating a curated software catalog
through `winget` or Chocolatey. It is written in PowerShell and Windows Forms, requires no web
runtime, and keeps package operations explicit and reviewable.

Version `1.2.0` rebuilds the project around a compact three-pane desktop shell, application-owned
contracts, isolated external adapters, and a custom window frame that remains consistent across
Windows themes.

## What Kapsel Does

- Loads a curated catalog of Windows applications from `src/applications.json`.
- Searches by application name, key, category, description, or package identifier.
- Filters applications by category and Free and Open Source Software status.
- Preserves selections while the user searches or changes category.
- Installs or updates multiple applications after explicit confirmation.
- Uses `winget` or Chocolatey only when the provider is installed and supported by the package.
- Skips unsupported selections and records the result in the activity panel.
- Opens the official website for the focused application.
- Displays product features, release changes, provider state, and operation activity in the UI.

Kapsel does not download arbitrary URLs, maintain its own package repository, or bypass package
manager security controls. `winget` and Chocolatey remain responsible for package resolution,
download, validation, installation, and updates.

## Product Journey

```txt
Open Kapsel
  -> choose a package provider
  -> find and select applications
  -> choose Install or Update
  -> review the confirmation
  -> Kapsel executes supported package commands
  -> inspect the result in Activity
```

## Interface

The desktop shell follows a compact three-pane model:

| Surface | Responsibility |
| --- | --- |
| Window bar | Application identity, window drag area, minimize, maximize, restore, and close. |
| Left navigation | Product identity, active package provider, categories, and version context. |
| Catalog workspace | Search, FOSS filtering, catalog metrics, selection, install, and update actions. |
| Context panel | Activity, current features, and release changes. |
| Status bar | Visible catalog count and package-operation status. |

All descriptive and informational text is rendered with labels. Only controls that accept user
input, such as search and checkboxes, are editable or selectable.

| Shortcut | Action |
| --- | --- |
| `Ctrl+F` | Focus catalog search. |
| `Escape` | Clear a non-empty search. |

## Requirements

- Windows 10 or Windows 11.
- Windows PowerShell 5.1 or newer.
- `winget` recommended.
- Chocolatey optional.
- JetBrains Mono recommended; Kapsel falls back to Segoe UI when unavailable.
- Node.js 24 or newer only for repository command aliases and release builds.
- Pester for local tests.

## Run Kapsel

From PowerShell:

```powershell
.\kapsel.ps1
```

From Command Prompt or Explorer:

```cmd
kapsel.cmd
```

When Windows associates `.ps1` files with an editor, use `kapsel.cmd` or run the script from a
terminal. The wrapper starts PowerShell with a process-scoped execution-policy bypass.

Available commands:

```powershell
.\kapsel.ps1 ui
.\kapsel.ps1 help
.\kapsel.ps1 version
```

Repository aliases:

```powershell
npm start
npm run dev
npm run app
npm run help
npm run version
```

`start`, `dev`, and `app` all open the local Windows Forms application through the same
repository-relative STA launcher.

## Install Launchers

Install the launchers for the current user and add their directory to the user `PATH`:

```powershell
.\install.ps1 -AddToUserPath
```

Use a custom location when required:

```powershell
.\install.ps1 -InstallDirectory "$env:USERPROFILE\Tools\Kapsel" -AddToUserPath
```

Open a new terminal after changing `PATH`, then run `kapsel`.

## Catalog Contract

Browse the complete generated list in [CATALOG.md](./CATALOG.md).

The source catalog remains at `src/applications.json` for backward compatibility and manual
maintenance. Each top-level property is a stable application key:

```json
{
  "sevenzip": {
    "category": "Utilities",
    "content": "7-Zip",
    "description": "File archiver",
    "link": "https://www.7-zip.org/",
    "winget": "7zip.7zip",
    "choco": "7zip",
    "foss": true
  }
}
```

| Field | Contract |
| --- | --- |
| Top-level key | Unique, stable identifier used to preserve selection and map UI rows. |
| `category` | User-facing category. Empty values normalize to `Uncategorized`. |
| `content` | Required display name. |
| `description` | Short factual description. |
| `link` | Official project, publisher, or product page. |
| `winget` | Exact package identifier, or `na` when unavailable. |
| `choco` | Exact Chocolatey package identifier, or `na` when unavailable. |
| `foss` | Boolean identifying Free and Open Source Software. |

Kapsel treats persisted JSON as untrusted input. The infrastructure adapter parses the document,
then the domain layer normalizes and validates every catalog entry before presentation.

## Package Workflow

Package execution has four explicit stages:

1. Presentation sends selected applications and a provider to the application service.
2. Application separates supported and unsupported entries.
3. Domain creates a structured command description without executing a process.
4. Infrastructure starts the package manager and returns its exit code.

Generated commands use exact package identifiers and non-interactive agreement flags. Kapsel never
constructs a command from a free-form user command string.

## Architecture

```txt
Presentation / WinForms
        |
Application use cases
        |
Domain rules and command descriptions

Composition root --------> Infrastructure adapters
        |
Shared product metadata
```

Dependency direction is enforced by tests: Domain has no UI, filesystem, or process dependency;
Application has no Presentation or Infrastructure import. The WinForms composition root is the
only place allowed to wire use cases to concrete adapters.

```txt
src/
  Kapsel.ps1
  applications.json
  modules/
    Application/
      CatalogService.psm1
      PackageService.psm1
    Domain/
      ApplicationCatalog.psm1
      PackageOperation.psm1
    Infrastructure/
      AssetProvider.psm1
      JsonCatalogRepository.psm1
      PackageManagerAdapter.psm1
    Presentation/WinForms/
      ApplicationGridView.psm1
      CatalogView.psm1
      ContextView.psm1
      Gui.psm1
      ShellView.psm1
      SidebarView.psm1
      Theme.psm1
      WindowChrome.psm1
    Shared/
      ProductMetadata.psm1
```

## Development

```powershell
npm run dev
npm run validate
npm test
npm run test:ui
npm run docs:catalog:check
npm run build:check
```

Remove generated release directories and ZIP files without touching other `dist` content:

```powershell
npm run clean:releases
```

For a full Windows release build:

```powershell
npm run build:release
```

The release build creates:

```txt
dist/releases/Kapsel-<version>-windows/
dist/releases/Kapsel-<version>-windows.zip
```

The executable depends on the adjacent `src` and `assets` directories. Distribute the generated
ZIP archive, not `Kapsel.exe` by itself.

## Release Automation

Update `package.json` and `ProductMetadata.psm1` to the same version, commit the release, then push
a matching semantic-version tag:

```powershell
git tag v1.2.0
git push origin v1.2.0
```

The Quality workflow validates source changes and pull requests. The Release workflow runs the
same checks, builds the distributable ZIP, and publishes it only from a matching version tag.

## Documentation

| Document | Purpose |
| --- | --- |
| [README.md](./README.md) | Product overview, setup, operation, and contributor entry point. |
| [CATALOG.md](./CATALOG.md) | Generated list of available applications and package identifiers. |
| [CHANGELOG.md](./CHANGELOG.md) | Released user-visible, architectural, catalog, and packaging changes. |
| [CONTRIBUTING.md](./CONTRIBUTING.md) | Issue, catalog, branch, commit, and pull-request workflow. |

## Project Status

`v1.2.0` is the clean-architecture and desktop-shell release. Kapsel remains focused on one job:
making a curated Windows application catalog easy to search, install, and update from one native
interface.

Read [CONTRIBUTING.md](./CONTRIBUTING.md) before opening an issue or pull request.

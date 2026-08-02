# Contributing to Kapsel

Thanks for taking the time to improve Kapsel. This project is intentionally small, native, and manually maintainable, so contributions should keep the architecture clear and the catalog trustworthy.

## Before You Start

Open an issue before working on:

- UI or UX redesigns.
- Changes to install or update behavior.
- New package manager support.
- Large catalog additions or reorganizations.
- Anything that may affect existing workflows.

Small fixes, typo corrections, and clearly safe catalog additions can go straight to a pull request.

## Reporting Issues

Use `.github/ISSUE_TEMPLATE.md` when opening an issue.

Include:

- What happened.
- What you expected to happen.
- Steps to reproduce.
- Windows version.
- PowerShell version.
- Whether `winget` and Chocolatey are installed.
- Screenshots for visual issues.
- Error output when available.

For package issues, include the application key from `src/applications.json` and the failing provider (`winget` or `choco`).

## Pull Request Workflow

1. Create a feature branch from the latest main branch.
2. Keep the change focused on one purpose.
3. Follow the existing module boundaries.
4. Update docs when behavior, UI, catalog shape, or usage changes.
5. Run local validation.
6. Open a pull request using `.github/PULL_REQUEST_TEMPLATE.md`.

Suggested branch names:

```txt
fix/category-selection
feat/catalog-devtools
ui/refine-main-layout
docs/contributing-guide
```

## Architecture Guidelines

Keep the clean separation between modules:

- `Applications.psm1`: catalog and package-manager operations only.
- `ApplicationGrid.psm1`: grid/table behavior only.
- `ApplicationInfo.psm1`: Activity, Features, and Changelog section only.
- `ApplicationMain.psm1`: main layout composition only.
- `ApplicationSidebar.psm1`: sidebar layout and category/provider controls only.
- `Assets.psm1`: asset path resolution only.
- `Branding.psm1`: product metadata only.
- `Gui.psm1`: app composition and event wiring only.
- `UiTheme.psm1`: shared visual primitives and theme helpers only.

Avoid putting business logic inside UI construction modules when it belongs in `Applications.psm1`.

## UI Guidelines

- Keep the app dark, compact, and utility-focused.
- Do not use editable text fields for visual-only descriptions or documentation blocks.
- Avoid text overlap at the minimum supported window size.
- Prefer shared helpers from `UiTheme.psm1` over one-off styling.
- Keep controls aligned and predictable.
- Validate that the app opens after changing WinForms layout code.

## Catalog Guidelines

Catalog entries live in `src/applications.json`.

Every entry must include:

```json
{
  "category": "Utilities",
  "content": "Application Name",
  "description": "Short user-facing description.",
  "link": "https://official-project-page.example/",
  "winget": "Publisher.Package",
  "choco": "package-name",
  "foss": true
}
```

Rules:

- Use a unique, lowercase, stable key when possible.
- Use the official website or official repository for `link`.
- Prefer exact `winget` ids from official manifests.
- Use `na` when a provider is unavailable.
- Keep descriptions concise and factual.
- Set `foss` only when the application is Free and Open Source Software.
- Do not add abandoned, unsafe, or unclear packages without opening an issue first.

## Validation

Run syntax validation:

```powershell
$files = Get-ChildItem -Recurse -Include *.ps1,*.psm1
foreach ($file in $files) {
    $tokens = $null
    $errors = $null
    [System.Management.Automation.Language.Parser]::ParseFile($file.FullName, [ref] $tokens, [ref] $errors) | Out-Null
    if ($errors.Count -gt 0) { throw "$($file.FullName): $($errors[0].Message)" }
}
```

Run tests:

```powershell
Invoke-Pester .\tests
```

Check the entrypoint:

```powershell
.\kapsel.ps1 version
```

For UI changes, also launch the app and inspect the main workflows:

```powershell
.\kapsel.ps1
```

Verify:

- The window opens.
- Applications are visible.
- Categories filter correctly.
- Search works.
- `FOSS only` works.
- Selection count updates.
- Install/update buttons are disabled when nothing is selected.

## Pull Request Checklist

Before opening a PR:

- The change is scoped and easy to review.
- PowerShell syntax validation passes.
- Pester tests pass.
- UI changes were manually smoke-tested.
- Docs were updated when needed.
- New catalog entries use official links and valid package ids.
- No unrelated files were reformatted or changed.

## Commit Messages

Use short, clear commit messages:

```txt
feat(catalog): add development tools
fix(ui): keep action buttons disabled without selection
docs: add contribution guide
```

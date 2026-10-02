# Testing

## Baseline Gates

Run `npm run check` for the local/CI baseline: syntax, Pester, generated catalog, documentation
links/version consistency, and release packaging. Node.js 24+ and Pester 4.10.1 are required.
See [Development](DEVELOPMENT.md) for setup.

`npm run test:tooling` runs Node's built-in tests for documentation link validation, including
broken targets, duplicate heading anchors, encoded paths, fenced examples and release-tree escapes.

`npm run validate` uses PowerShell's parser. It checks syntax, not style, provider behavior or
runtime correctness. PSScriptAnalyzer is not currently part of the repository gates.

## Test Ownership

| Location | Responsibilities |
| --- | --- |
| `tests/Domain` | Literal search, normalization, command flags, outcomes, inventory parsing, favorites |
| `tests/Application` | Use cases, injected adapters, batch event behavior and runspace orchestration |
| `tests/Infrastructure` | Catalog/preferences I/O and package process result contracts |
| `tests/Architecture.Tests.ps1` | Required module organization and dependency guardrails |
| `tests/Fixtures/PackageUi.ps1` | Real WinForms shell with simulated package/inventory adapters |

Tests must not install/update/remove software or depend on a provider being installed. Use
temporary storage and injected scriptblocks. A worker recreates a scriptblock in its own runspace,
so make fixtures self-contained rather than closure-dependent.

To run an owning suite from **Windows PowerShell**:

```powershell
Import-Module Pester -RequiredVersion 4.10.1 -ErrorAction Stop
Invoke-Pester .\tests\Domain -EnableExit
```

The repository `npm test` command fails if Pester 4.10.1 is unavailable or any test fails. Keep
regressions at the boundary where the behavior can be observed; avoid tests that only restate code.

## Interactive Smoke Tests

```powershell
npm run test:ui
npm run test:ui:packages
```

Both need an unlocked Windows desktop with UI Automation. Do not run them concurrently: each
creates and exercises an actual window. The ordinary smoke test also queries real inventory when
a provider is present, and can fail because a configured provider/source is unavailable.

`test:ui:packages` forcibly chooses the fixture launcher. It tests install/update confirmations,
background progress, responsive search, unchanged results and failure details without installing
anything. It is the appropriate package UI regression gate.

Capture a screenshot or exercise a packaged launcher:

```powershell
.\scripts\Test-UiSmoke.ps1 -ScreenshotPath .\dist\ui-smoke.png
.\scripts\Test-UiSmoke.ps1 -LauncherPath .\dist\releases\Kapsel-1.3.0-windows\kapsel.ps1
.\scripts\Test-UiSmoke.ps1 -ExercisePackageActions -WindowWidth 1180 -WindowHeight 700
```

Replace the package path with the current version. For an optional executable, use its path as
`-LauncherPath`; do not combine it with `-ExercisePackageActions`, which always uses the fixture.

## Manual UI Matrix

For relevant presentation changes, record:

- Search via `Ctrl+F`, clearing via `Escape`, tab order and focused control visibility.
- Categories, FOSS, favorites, inventory filters and preserved hidden selections.
- Missing provider, scanning, empty result, inventory failure and partial update-check failure.
- Confirmation cancellation, simulated success/unchanged/failure, disabled actions and blocked close.
- Minimum 1180 x 700 layout, maximize/restore, resize edges and multi-monitor movement.
- 100/125/150/200% display scale and font fallback when text metrics change.

Existing automated smoke tests cover only part of this matrix. Do not describe manual accessibility,
high-DPI or Windows-version checks as automated guarantees.

## Documentation and Package Gates

`scripts/Validate-Documentation.mjs` checks repository Markdown inline links/images, HTML asset
links, relative target files, Markdown heading anchors, product-version agreement and Node-version
configuration. It intentionally skips external URL availability and links inside fenced code.
Use ordinary inline relative links for local documentation; reference-style links and complex HTML
are not a general Markdown-parser contract.

`build.ps1` copies the guides/assets/notices, checks documentation within the packaged tree, creates
the ZIP and verifies archive entries against staged files. This catches omitted linked guides or
licenses; it does not prove a clean-machine GUI launch, publisher identity or package installation.

Process/inventory fixture coverage can be extended as behavior changes. Interactive desktop smoke
tests are not currently run in CI.

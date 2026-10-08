# Kapsel Changelog

This file records user-visible and architectural changes. Release dates are added when a version is
published; unreleased work is identified explicitly.

## Unreleased

- Add Stop pending and confirmed Retry failed actions; active installers are never killed by cancellation.
- Warn after two minutes per package, retaining elapsed times and results while waiting safely.
- Keep previous inventory during refresh/failure and label its provider, timestamp and freshness.

- Speed up literal catalog search with a single-pass filter and coalesce rapid search edits.
- Batch select/clear updates, preserve focused rows, sort order and scroll position, and show visible/hidden/provider-supported selection counts.
- Add focused-app details with full descriptions, exact provider IDs, detected versions and update-check confidence.
- Explain empty search, favorites, inventory-loading and unavailable-update states.
- Keep selection feedback and all primary actions visible at the minimum window size; enable DPI layout scaling.
- Add keyboard catalog selection, region navigation and refresh, with accessible names and regression coverage.
- Validate preference schemas and contents, protect damaged/future files from overwrite, and replace valid files atomically.
- Diagnose provider paths, versions and inventory capabilities in the background; retain exit codes and distinguish source, permission and parsing failures.
- Expand deterministic inventory/process tests and simulated desktop checks, including isolated favorite persistence.
- Add a repeatable catalog performance measurement command.
- Move canonical product, contribution, catalog, and release-history documents to the repository root.
- Add user, development, architecture, testing, catalog, configuration, troubleshooting, and release guides.
- Add MIT licensing, support, and community guidance.
- Align local tooling and CI on the recorded Node.js major version and add documentation checks.
- Include linked documentation and license notices in release archives and validate packaged contents.

## 1.3.0 - Persistent Favorites (2026-09-17)

- Add persistent application favorites with a dedicated catalog filter.
- Store user preferences outside the installation directory under the current Windows profile.

## 1.2.6 - Package Operations and Readability (2026-09-12)

- Fixed the install/update confirmation error that closed the application.
- Run package operations in the background with per-application progress and elapsed time.
- Detect installed applications and available updates in the background for winget and Chocolatey.
- Add provider-specific inventory states, installed/update filters, and refresh after package actions.
- Add locally bundled icons to actions, filters, and context tabs.
- Prevent overlapping batches and closing the window during package execution.
- Explain no-update and already-installed results in Activity without marking them as failures.
- Show provider error details and batch summaries directly in Activity, retaining backup logs.
- Wrap context-panel text with automatic heights, larger type, and clearer section headings.
- Preserve the Activity reading position when new messages arrive.
- Default release archives to the PowerShell and CMD launchers; keep executable builds opt-in.
- Use STA launchers and preserve startup errors for inspection.
- Add background-operation, provider-result, and simulated package UI regression coverage.
- Make the test command fail when the required Pester version is missing or tests fail.

## 1.2.0 - Clean Architecture and Desktop Shell

- Reorganized production code into Domain, Application, Infrastructure, Presentation, and Shared
  layers.
- Added architecture tests that prevent Domain and Application dependency regressions.
- Separated package command construction from provider process execution.
- Added injected package execution for deterministic tests.
- Added catalog key, package identifier, URL, and FOSS validation.
- Made catalog search literal and case-insensitive.
- Preserved selections while searching and changing categories.
- Rebuilt the interface as a compact three-pane desktop shell.
- Replaced remaining light system tabs, filters, and catalog scrolling surfaces with neutral dark
  application-owned controls.
- Replaced native Windows chrome with a borderless application-owned title bar, window controls,
  drag handling, and edge resizing.
- Added compact metrics, focused provider controls, and a right context panel.
- Added process-level UI smoke testing for source and packaged executable launchers.
- Replaced the single issue template with bug, feature, and catalog issue forms.
- Consolidated public documentation into the README, catalog, changelog, contribution guide, and
  repository templates.
- Added a category-grouped public application catalog generated from `applications.json` and
  enforced by GitHub Actions.
- Corrected the GitHub Desktop Chocolatey identifier to `github-desktop`.
- Added a stable STA development launcher shared by `start`, `dev`, and `app`.
- Added `clean:releases` for scoped removal of generated release artifacts.

## 1.1.x - Catalog and Distribution

- Expanded the curated application catalog.
- Added winget and Chocolatey provider selection and compatibility handling.
- Added dark Windows Forms styling with JetBrains font preference.
- Added optional application image and window icon loading.
- Added Activity, Features, and Changelog views.
- Added executable and ZIP release packaging with `ps2exe`.
- Added semantic-version GitHub Release automation.
- Added initial contribution and pull-request documentation.

## 1.0.0 - Initial Catalog Installer

- Added the native Windows Forms application.
- Added local JSON catalog loading.
- Added category navigation, search, FOSS filtering, and multi-selection.
- Added winget and Chocolatey install/update commands.
- Added PowerShell and Command Prompt launchers.

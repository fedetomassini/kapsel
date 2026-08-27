# Kapsel Changelog

This file records user-visible and architectural changes. Release dates are added when a version is
published; unreleased work is identified explicitly.

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

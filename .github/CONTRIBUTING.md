# Contributing to Kapsel

Kapsel is intentionally focused and manually maintainable. Contributions should preserve its
catalog-installer purpose, clean dependency direction, and predictable package workflow.

## Before Starting

Read:

- [README.md](./README.md) for product behavior and local commands.

Open an issue before implementing:

- A new package provider.
- A catalog schema change.
- A major interface redesign.
- A change to install, update, elevation, or process behavior.
- A large catalog addition or category reorganization.
- A feature that expands Kapsel beyond curated application installation and updates.

Small documentation fixes and verified catalog corrections may go directly to a pull request.

## Issues

Choose the matching GitHub issue form:

- Bug report for incorrect behavior or a regression.
- Feature request for product changes.
- Catalog request for application additions or metadata corrections.

For package failures, include the application key, selected provider, package identifier, Kapsel
version, Windows version, and the visible Activity result. Do not include credentials or unrelated
environment data.

## Development Setup

Requirements:

- Windows PowerShell 5.1 or newer.
- `winget` or Chocolatey for manual package-operation testing.
- Node.js 24 or newer for npm aliases.
- Pester available to Windows PowerShell.

Clone the repository, create a branch, and validate the baseline:

```powershell
npm run validate
npm test
npm run build:check
```

Run the application:

```powershell
npm run dev
```

## Branches and Commits

Use a short branch name describing one purpose:

```txt
fix/catalog-search
feat/package-state
ui/context-panel
docs/release-process
catalog/add-development-tools
```

Use conventional, scoped commit messages:

```txt
fix(domain): treat search characters literally
feat(catalog): add verified media tools
refactor(ui): separate context view composition
docs: define release rollback procedure
```

Do not mix catalog expansion, UI redesign, and architecture changes in one pull request unless they
are inseparable parts of one approved milestone.

## Architecture Contributions

Dependency direction is mandatory:

```txt
Presentation -> Application -> Domain
Composition root -> Infrastructure
```

- Put deterministic catalog and command rules in Domain.
- Put user-facing use cases and orchestration in Application.
- Put files, processes, command discovery, and image conversion in Infrastructure.
- Put controls and visual state in Presentation.
- Wire concrete adapters only in the composition root.
- Add Shared code only when multiple entry points need one stable product contract.

Do not move business behavior into an event handler to avoid creating the correct application
function.

## Catalog Contributions

Each entry must follow the catalog contract in [README.md](./README.md#catalog-contract). Before
submission:

- Use a unique stable key.
- Use an official application or publisher page.
- Verify the exact `winget` identifier.
- Verify the exact Chocolatey identifier when supplied.
- Use `na` when a provider is unavailable.
- Write a concise factual description.
- Mark FOSS only when the license qualifies.
- Confirm the entry is not already present under another key.
- Keep changes alphabetically or categorically coherent with nearby entries when practical.

For larger additions, explain the selection criteria in the issue or pull request.

Regenerate the public application list after every catalog change:

```powershell
npm run docs:catalog
```

## UI Contributions

- Preserve the compact three-pane layout.
- Preserve the custom borderless window bar and edge resizing behavior.
- Use theme primitives and existing spacing.
- Keep descriptive text non-editable and non-selectable.
- Preserve the minimum `1180 x 700` layout.
- Test with and without JetBrains Mono installed when changing text metrics.
- Verify provider buttons, category navigation, search, selection, and action disabled states.
- Include a screenshot in the pull request.

## Tests

Add tests at the owning boundary:

- Domain behavior in `tests/Domain`.
- Use-case behavior in `tests/Application`.
- External adapter behavior in `tests/Infrastructure`.
- Dependency constraints in `tests/Architecture.Tests.ps1`.

Automated tests must not install, update, or remove software. Inject a process adapter when testing
package orchestration.

## Pull Request Checklist

Before opening a pull request:

- The change has one clear purpose.
- Syntax validation passes.
- Pester tests pass.
- Build check passes.
- Generated catalog check passes.
- UI changes were opened and manually smoke-tested.
- New behavior includes proportional tests.
- Public documentation is accurate.
- Catalog identifiers and links were verified.
- No generated `dist` files, credentials, or unrelated formatting are included.

Use the repository pull-request template and link the relevant issue with `Closes #<number>` when
applicable.

## Review Expectations

Review prioritizes correctness, package safety, dependency direction, maintainability, UI behavior,
and catalog accuracy. A working feature may still require changes if it couples layers or makes
future catalog maintenance harder.

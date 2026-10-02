# Documentation

Kapsel's docs describe shipping behavior. Start at the root [README](../README.md) for launch instructions.

## Users

| Guide | Use it for |
| --- | --- |
| [User guide](USER_GUIDE.md) | Discovery, selection, favorites, inventory and confirmed package actions |
| [Configuration and data](CONFIGURATION.md) | Runtime, launchers, user files and environment variables |
| [Troubleshooting](TROUBLESHOOTING.md) | Startup, providers, inventory, preferences and package failures |
| [Application catalog](../CATALOG.md) | Generated application list |
| [Support](../SUPPORT.md) | Reporting a reproducible problem |

## Contributors and Maintainers

| Guide | Use it for |
| --- | --- |
| [Contributing](../CONTRIBUTING.md) | Branches, reviews, catalog/UI expectations and contribution terms |
| [Development](DEVELOPMENT.md) | Local setup, commands and change workflow |
| [Architecture](ARCHITECTURE.md) | Layer ownership, worker lifecycle and adapter contracts |
| [Testing](TESTING.md) | Pester boundaries, fixtures and UI smoke tests |
| [Catalog maintenance](CATALOG.md) | Source schema, normalization and provider-ID verification |
| [Releasing](RELEASING.md) | Versioning, package contents, publication and recovery |
| [Changelog](../CHANGELOG.md) | Released history and unreleased repository changes |

## Documentation Rules

- Root documents are canonical; `.github` contains workflows, forms and legacy document pointers.
- Use relative links to tracked files and Markdown headings so the same guides work offline in a ZIP.
- Keep descriptions in English, following the existing documentation and UI convention.
- Update a guide with the command, behavior, persistent-format or public-contract change it describes.
- Generate `CATALOG.md` with `npm run docs:catalog`; do not hand-edit it.
- Run `npm run docs:check` for local links/anchors and version consistency, and
  `npm run docs:catalog:check` for generated catalog drift. External website availability is not
  checked by the offline documentation gate.
- Add new guide entry points here; update `build.ps1` if a guide needs an additional bundled asset.

There is no separate documentation-site generator or dependency install. Markdown is shipped with
the release. Directory-level READMEs provide navigation, not duplicate API specifications.

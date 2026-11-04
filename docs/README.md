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
| [Performance](PERFORMANCE.md) | Deterministic catalog benchmark, baseline and comparison method |
| [Catalog maintenance](CATALOG.md) | Source schema, normalization and provider-ID verification |
| [Distribution](DISTRIBUTION.md) | Source-only distribution, launcher setup and future signed builds |
| [Changelog](../CHANGELOG.md) | Released history and unreleased repository changes |

## Documentation Rules

- Root documents are canonical; `.github` contains workflows, issue forms, the PR template and assets.
- Use relative links to tracked files and Markdown headings so the guides work offline in a checkout.
- Keep descriptions in English, following the existing documentation and UI convention.
- Update a guide with the command, behavior, persistent-format or public-contract change it describes.
- Generate `CATALOG.md` with `npm run docs:catalog`; do not hand-edit it.
- Run `npm run docs:check` for local links/anchors and version consistency, and
  `npm run docs:catalog:check` for generated catalog drift. External website availability is not
  checked by the offline documentation gate.
- Add new guide entry points here and keep relative assets beside the documents that use them.

There is no separate documentation-site generator or dependency install. Markdown ships with the
repository. Directory-level READMEs provide navigation, not duplicate API specifications.

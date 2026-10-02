# Domain

These modules contain deterministic rules, with no filesystem, process or Windows Forms calls.

| Module | Owns |
| --- | --- |
| `ApplicationCatalog.psm1` | Catalog normalization/validation, literal search, categories and provider support |
| `PackageOperation.psm1` | Structured provider commands and numeric exit-code outcomes |
| `PackageInventory.psm1` | Provider-output parsing, package-ID matching and inventory snapshots |
| `UserPreferences.psm1` | Favorite-key normalization and toggling |

Add proportional behavior tests in `tests/Domain`. Preserve stable statuses/keys independently of UI
text. A new rule belongs here when it can be evaluated from input without I/O.
See [Architecture](../../../docs/ARCHITECTURE.md) and [Catalog maintenance](../../../docs/CATALOG.md).

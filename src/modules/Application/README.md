# Application

Application services coordinate user-facing use cases and import Domain, not Infrastructure or
Presentation. Concrete I/O is passed as scriptblocks by composition roots/workers.

| Module | Owns |
| --- | --- |
| `CatalogService.psm1` | Catalog snapshot and discovery use cases |
| `PackageService.psm1` | Supported/unsupported plan, availability checks and one package action |
| `InventoryService.psm1` | Provider inventory interpretation and installed/update filtering |
| `PreferenceService.psm1` | Favorite loading/saving with injected storage |

Keep command construction and status semantics in Domain. Put I/O in adapters rather than importing
an adapter here. Tests live in `tests/Application`; runner tests there also cover presentation-owned
runspace orchestration. See [Architecture](../../../docs/ARCHITECTURE.md) for actual contracts.

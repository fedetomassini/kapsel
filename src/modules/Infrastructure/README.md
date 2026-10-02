# Infrastructure

This layer owns external I/O. It returns structured data and errors rather than manipulating controls.

| Module | Boundary |
| --- | --- |
| `JsonCatalogRepository.psm1` | Catalog path and JSON parsing |
| `JsonPreferencesRepository.psm1` | User preference location, JSON and staged writes |
| `PackageManagerAdapter.psm1` | Provider discovery, package processes and redirected stdout/stderr |
| `PackageInventoryAdapter.psm1` | Read-only provider scans, timeout/cancellation and temporary export cleanup |
| `AssetProvider.psm1` | Local image/icon asset loading |

Preserve provider exit codes and actionable diagnostics. Package execution currently waits without a
timeout; inventory processes do have a timeout/cancellation contract. Do not conflate them.
Tests live in `tests/Infrastructure`. See [Architecture](../../../docs/ARCHITECTURE.md) and
[Configuration](../../../docs/CONFIGURATION.md) for storage and process behavior.

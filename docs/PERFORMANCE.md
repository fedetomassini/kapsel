# Performance Baseline

Kapsel measures deterministic catalog components without querying providers or installing software.
The numbers below are an indicative local baseline, not a service-level guarantee. Provider
inventory queries, package processes, painting and full application startup are excluded.

## Run the Benchmark

```powershell
npm run bench:catalog
```

The script writes `dist/catalog-performance.json` with the runtime, OS, processor, iteration count
and per-size results. For a custom run:

```powershell
.\scripts\Measure-CatalogPerformance.ps1 -Sizes 254, 1000, 5000 -Iterations 10 -OutputPath .\dist\catalog-performance.json
```

It measures the shipped catalog plus synthetic 1,000 and 5,000 application sets. Synthetic entries
reuse catalog names and descriptions with unique provider IDs, so search and inventory mapping stay
representative without duplicate identifiers. Each component is warmed once and then averaged.

| Component | What it covers |
| --- | --- |
| Catalog load | Read `src/applications.json`, validate and build the snapshot (once per run) |
| Literal search | `Find-KapselApplications` with the `firefox` search term |
| Category filter | `Find-KapselApplications` with the first category and no search |
| Inventory mapping | winget export conversion plus installed/update state projection |
| Grid bind | Rebuild the DataGridView rows with half the applications selected |
| Select and clear | Toggle every visible row selected, then clear |

## Recorded Baseline

Recorded 2026-10-31 on Windows 11 (`10.0.26300`), Windows PowerShell `5.1.26100.9711`, AMD Ryzen 7
5700, 64-bit process, 5 warmed iterations. Values are milliseconds.

| Applications | Catalog load | Literal search | Category filter | Inventory mapping | Grid bind | Select + clear |
| --- | --- | --- | --- | --- | --- | --- |
| 254 (shipped) | 215.8 | 0.9 | 0.3 | 10.5 | 9.8 | 82.1 |
| 1,000 synthetic | — | 2.7 | 0.6 | 40.6 | 30.0 | 302.6 |
| 5,000 synthetic | — | 15.4 | 3.4 | 232.6 | 149.9 | 1,590.8 |

Catalog load is a one-time startup component. Search and category filters stay well below an
interaction budget at every measured size. Grid binding and bulk selection dominate larger
catalogs; that is why virtualization remains deferred until a real catalog justifies the added
complexity. The shipped 254-application catalog is far below those thresholds.

## Compare a Change

Run the benchmark before and after the change on the same machine and power plan, with other
applications closed. Keep the iteration count equal and compare the recorded JSON, not one isolated
run. Report the OS, PowerShell version and processor with any comparison. Do not present local
numbers as cross-machine performance claims.

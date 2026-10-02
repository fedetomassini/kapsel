# Architecture

Kapsel is a Windows PowerShell application using Windows Forms. There is no web server, database,
dependency injection container or npm runtime. Modules establish responsibility boundaries;
PowerShell objects and injected scriptblocks carry the existing contracts.

## Layer Ownership

```text
kapsel.cmd / kapsel.ps1 / scripts/Start-Kapsel.ps1
  -> src/Kapsel.ps1 (command dispatch and metadata)
    -> Presentation/WinForms/Gui.psm1 (composition root)
      -> Application -> Domain
      -> Infrastructure (concrete I/O)
      -> Shared (product identity/version)
```

| Layer | Owns | Must not own |
| --- | --- | --- |
| Domain | Catalog normalization/search, provider command descriptions, outcomes, inventory parsing, favorite-key rules | WinForms, filesystem, process execution |
| Application | Catalog snapshots, package plans/actions, inventory mapping/filtering, preference use cases | Concrete adapters or UI imports |
| Infrastructure | JSON reads/writes, executable discovery/execution, inventory queries, asset loading | User-interaction decisions or controls |
| Presentation/WinForms | Views, events, current selection/filter state, UI timers and worker coordination | Reimplementing domain command/outcome rules |
| Shared | Product name/version/creator/description | Generic helpers or unrelated mutable state |

`tests/Architecture.Tests.ps1` checks the principal dependency constraints. Its source checks are
guardrails, not a complete static dependency graph. `Gui.psm1` wires use cases to adapters; the
worker modules create separate runspaces and import the adapters they need in that execution context.

## Entry Points

- Root launchers start Windows PowerShell in STA and preserve errors for inspection.
- `src/Kapsel.ps1` supports `ui` (also `app`/`apps`), `help` (also `--help`/`-h`), and `version`.
- `scripts/Start-Kapsel.ps1` resolves the root launcher independently of the current directory.
- `install.ps1` writes per-user wrappers referring to the absolute source entry point; it does not
  copy the distribution.
- `ProductMetadata.psm1` supplies app/build identity; `package.json` must have the same version.

## Catalog Flow

```text
JsonCatalogRepository reads applications.json
  -> CatalogService requests a snapshot
    -> Domain normalizes/validates entries
      -> Presentation stores selection by stable Key and renders filtered rows
```

Normalized applications contain `Key`, `Name`, `Category`, `Description`, `Link`, `WingetId`,
`ChocoId`, `PreferredProvider`, and `Foss`. Provider IDs normalize to null when absent or `na`.
Search is literal and ordinal case-insensitive. Filtering does not own or reset the selection set.
See [Catalog maintenance](CATALOG.md) for authoring rules and compatibility behavior.

## Package Contracts

| Boundary | Existing contract |
| --- | --- |
| `New-KapselPackagePlan` | `{ Provider, Supported[], Unsupported[] }` |
| `New-KapselPackageCommand` | `{ Executable, Arguments: string[], Display }`; describes only, does not execute |
| Injected `ProcessInvoker` | Receives a command; returns an object with `ExitCode`, optionally `Diagnostics` |
| `Invoke-KapselPackageProcess` | Returns `{ ExitCode, Diagnostics, LogPaths[] }`; owns redirected output files |
| `Invoke-KapselPackageAction` | Returns app/provider/action/exit code, success/status/message, display command and diagnostics |

The action service checks provider availability, builds the domain command and classifies its exit
code. Internal actions are `Install`/`Upgrade`; UI wording uses Install/Update. winget commands use
exact IDs, silent mode and agreement flags; Chocolatey commands use `install`/`upgrade` and `-y`.
No free-form shell command is accepted from a user. Catalog validation is part of this trust boundary.

Outcomes are `Completed`, `UpToDate`, `AlreadyInstalled`, `RestartRequired`, or `Failed`.
Classification is numeric, not based on translated console text. Unknown non-zero codes fail;
Chocolatey 1641/3010 are restart successes and code 2 is unchanged for upgrades. Relevant winget
codes are maintained in `Domain/PackageOperation.psm1` with upstream references.

## Background Workers

`PackageOperationRunner.psm1` creates a PowerShell runspace and processes supported apps serially.
It puts `Started`, `Completed`, or `Failed` objects onto a concurrent queue. A WinForms timer
(200 ms) consumes events on the UI thread. Workers do not access controls. The worker's invoker
scriptblock is recreated from source in the new runspace, so injected fixtures must not rely on
capturing variables from the caller's session.

While a batch is active, the UI blocks overlapping actions and closing. Failures are recorded per
app and the loop continues. Progress counts completed entries. On completion the UI disposes the
worker and requests a new inventory scan. Package execution uses `Start-Process -Wait` without a
timeout/cancel policy.

`InventoryRunner.psm1` produces one snapshot in a separate runspace. A 250 ms UI timer consumes it.
Provider switches cancel stale scans; completed results are applied only to the active provider.
Pending refresh requests are coalesced. The scan and cancellation source are disposed after
completion and during form cleanup.

## Inventory Contracts

- winget: `export --include-versions` to a temporary JSON file, then
  `list --upgrade-available` for updates. Export data maps IDs/versions; update IDs are matched from
  console text against known IDs, so localization/truncation requires fixture coverage.
- Chocolatey: `list --limit-output --no-color` and `outdated --limit-output --no-color`, parsed as
  pipe-delimited records.
- Each inventory subprocess has a 90-second default timeout and cancellation token. stdout/stderr
  are drained asynchronously; temporary winget export files are removed in `finally`.
- An update-query failure returns a warning and `UpdatesChecked = false` while retaining installed
  results. Installed-query failure fails the scan.
- A snapshot contains provider, per-key states/version/update-check success, counts and
  `UpdatesChecked`. Status is `Unsupported`, `NotDetected`, `Installed`, or `UpdateAvailable`.

Inventory is session-local and provider-specific; it is not a complete Windows software registry.

## Persistence and Diagnostics

Preferences use `{ SchemaVersion: 1, FavoriteKeys: string[] }`. The application layer normalizes
keys and injects the reader/writer. Infrastructure writes a sibling temporary file, then replaces
the destination using a move and cleans up the temporary path. Explicit schema-version rejection
and backup/recovery are not implemented yet.

Defaults and the `KAPSEL_DATA_DIRECTORY` preference override are documented in
[Configuration](CONFIGURATION.md). The override does not redirect package logs.
Activity is transient; provider stdout/stderr files persist without a retention policy today.

## Extending the App

Add deterministic rules to Domain, orchestration to Application, external I/O to Infrastructure,
and controls to Presentation. Inject concrete I/O at the owning composition boundary. Avoid a
provider framework, repository abstraction or generic service layer until a real contract requires
it. Changes to preferences, provider flags, stable keys or package contents need compatibility notes
and boundary tests. See [Testing](TESTING.md) and the directory READMEs under `src/modules`.

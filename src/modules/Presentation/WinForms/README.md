# Windows Forms Presentation

`Gui.psm1` composes the app, adapters and use cases. Views own controls; runners own background
execution contexts; UI timers consume results on the UI thread.

| Module | Responsibility |
| --- | --- |
| `ShellView.psm1`, `WindowChrome.psm1` | Main window, borderless frame, resize and window controls |
| `SidebarView.psm1` | Provider and category navigation |
| `CatalogView.psm1`, `ApplicationGridView.psm1` | Search, filters, selection, focused rows and actions |
| `ContextView.psm1` | Focused-app details, Activity, features and release information |
| `Theme.psm1` | Existing colors, fonts, icons and styling primitives |
| `InventoryRunner.psm1` | Background snapshot with cancellation |
| `PackageOperationRunner.psm1` | Serial background batch and concurrent event queue |

Workers must never mutate controls. Keep domain behavior out of event handlers. Preserve selection
by stable key, compact three-pane layout, label-based descriptive text and 1180 x 700 minimum size.
Use existing theme primitives; do not add a second styling system.

Grid refreshes preserve focus/scroll by key and sort order. Bulk selection updates the backing table
with binding notifications suppressed, then synchronizes once. Single-cell edits update one key.
Search edits are coalesced by the composition root; immediate actions flush pending search first.

For worker changes, exercise the simulated package UI. For metrics/chrome changes, inspect font
fallback, display scale, keyboard behavior and resize/maximize/restore.
See [Architecture](../../../../docs/ARCHITECTURE.md) and [Testing](../../../../docs/TESTING.md).

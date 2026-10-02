# Repository Scripts

Run scripts from a source checkout. npm aliases resolve them relative to the repository.

| Script | Responsibility |
| --- | --- |
| `Start-Kapsel.ps1` | Repository-relative STA launcher for start/dev/app/help/version |
| `Validate-PowerShell.ps1` | Syntax parse without app execution; ignores dist copies |
| `Generate-CatalogMarkdown.ps1` | Generate/check root CATALOG.md from validated JSON |
| `Validate-Documentation.mjs` | Offline relative links/anchors, required docs and version checks |
| `Test-UiSmoke.ps1` | Interactive UI Automation, optional screenshot and simulated package actions |
| `Clean-Releases.ps1` | Scoped cleanup of generated Kapsel release directories/ZIPs |

Root `build.ps1` owns staging, optional executable compilation, documentation verification and ZIP
creation. Root `install.ps1` creates per-user PATH wrappers; it does not copy the app.

See [Development](../docs/DEVELOPMENT.md) for the command matrix,
[Testing](../docs/TESTING.md) for interactive requirements, and [Releasing](../docs/RELEASING.md)
for package contents. The Node documentation script uses built-ins only.

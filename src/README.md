# Source

`Kapsel.ps1` dispatches UI/help/version commands. `applications.json` is the manually maintained
catalog, not generated output. The desktop composition root is `modules/Presentation/WinForms/Gui.psm1`.

| Directory | Responsibility |
| --- | --- |
| [Domain](modules/Domain/README.md) | Deterministic rules and command descriptions |
| [Application](modules/Application/README.md) | Use cases with injected external operations |
| [Infrastructure](modules/Infrastructure/README.md) | Files, processes, provider inventory and assets |
| [Presentation/WinForms](modules/Presentation/WinForms/README.md) | Native controls and background-worker coordination |
| [Shared](modules/Shared/README.md) | Product identity and version |

Read [Architecture](../docs/ARCHITECTURE.md) before adding modules and
[Catalog maintenance](../docs/CATALOG.md) before editing applications.

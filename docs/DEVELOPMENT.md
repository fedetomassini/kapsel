# Development

## Supported Environment

Kapsel targets Windows 10/11 with **Windows PowerShell 5.1**. Repository npm aliases explicitly use
`powershell.exe`; the app requires STA for Windows Forms. PowerShell 7 is not currently a tested
replacement. CI uses a Windows runner; it does not prove the full Windows 10/11 desktop matrix.

Use Node.js **24 LTS** for repository tooling. `.node-version` records the recommended major, CI
reads it, and `package.json` permits newer versions (`>=24`). Node is not part of the desktop runtime.
There are no npm dependencies or lockfile; `npm install`/`npm ci` are not setup steps for this repo.

Install Pester 4.10.1 from a Windows PowerShell session if missing:

```powershell
Install-Module Pester -RequiredVersion 4.10.1 -Scope CurrentUser -Force -SkipPublisherCheck
Import-Module Pester -RequiredVersion 4.10.1 -ErrorAction Stop
```

The install flag allows replacing the inbox Pester publisher version; tests still explicitly
require 4.10.1. If prompted for the NuGet provider or gallery trust, review and follow the PowerShell
Gallery setup instructions. Kapsel never installs test modules on app startup.

## First Run

```powershell
git clone https://github.com/fedetomassini/kapsel.git
Set-Location kapsel
node --version
$PSVersionTable.PSVersion
npm run check
npm run dev
```

winget/Chocolatey are needed for real inventory and manual package operations, not deterministic
Pester tests. UI checks need an unlocked interactive Windows desktop.

## Command Matrix

| Command | Purpose | Side effects / prerequisites |
| --- | --- | --- |
| `npm start`, `npm run dev`, `npm run app` | Open the same STA app launcher | Reads catalog/preferences and queries installed providers |
| `npm run help`, `npm run version` | CLI information | No GUI or package operation |
| `npm run validate` | Parse PowerShell syntax | Does not execute app code |
| `npm test` | Pester 4.10.1 suites | Fakes package execution; no software installation |
| `npm run test:tooling` | Documentation validator regression tests | Node built-in test runner; temporary fixtures |
| `npm run docs:catalog` | Regenerate root CATALOG.md | Writes generated Markdown from validated catalog |
| `npm run docs:catalog:check` | Check generated catalog drift | Read-only |
| `npm run docs:check` | Check local documentation links and versions | Node built-ins; no network |
| `npm run check` | Validate, test Pester/tooling, check docs/catalog, build package | Creates the script ZIP under dist/releases |
| `npm run test:ui` | Exercise real window and inventory | Interactive desktop; installed provider/source may be queried |
| `npm run test:ui:packages` | Exercise confirmations and background outcomes | Interactive desktop; fixture replaces real package execution |
| `npm run bench:catalog` | Measure warmed search, grid binding and bulk-selection components | STA; real and synthetic 1k/5k catalogs; writes dist/catalog-performance.json |
| `npm run build`, `npm run build:check` | Build and verify script ZIP contents | Creates release directory and archive, no executable compiler |
| `npm run build:release` | Build default release archive | Same script distribution as build check |
| `npm run build:exe` | Opt-in unsigned executable and ZIP | May install ps2exe from PowerShell Gallery |
| `npm run release` | Run complete local release checks and build | Does not publish or push a Git tag |
| `npm run clean`, `npm run clean:releases` | Remove Kapsel release artifacts | Scoped to matching release directories/ZIPs; see scripts |

## Change Workflow

1. Read [CONTRIBUTING.md](../CONTRIBUTING.md) and choose an owning layer.
2. For feature work, agree on observable acceptance criteria in the issue.
3. Preserve the existing module patterns (`Set-StrictMode`, explicit exports, injected I/O at use cases).
4. Make the smallest coherent change; update the relevant guide and `Unreleased` changelog.
5. Run targeted tests while iterating, then `npm run check`.
6. For UI/worker changes, run the relevant smoke test and inspect the real window.
7. Review `git diff --check` and the actual diff; keep generated dist files out of commits.

Use Windows PowerShell-compatible syntax, not PowerShell 7-only operators. Keep identifiers,
domain statuses and persistent keys independent of presentation text. Comments should explain a
non-obvious invariant or provider quirk rather than narrating a function body.

## Repository Tooling

- `.editorconfig` specifies new-file whitespace; it does not reformat existing sources automatically.
- `.gitattributes` keeps text diffs stable and CMD launchers CRLF; binary assets are marked explicitly.
- `.github/workflows/quality.yml` runs read-only checks plus local package creation for PRs/main.
- `.github/workflows/release.yml` additionally validates the release tag and publishes the archive.
- Dependabot checks GitHub Actions; there are no npm dependencies to upgrade today.

See [Testing](TESTING.md), [Architecture](ARCHITECTURE.md), and [Releasing](RELEASING.md) for
boundary contracts and package lifecycle details.

## Performance Measurement

`npm run bench:catalog` uses the same catalog service/grid functions as the app. Its JSON report
records runtime, processor, dataset size and warmed repetition counts. Synthetic entries repeat
real metadata with unique keys/names. Compare runs on the same machine and with the same parameters.
The timings exclude painting, composition-root event handlers, startup and provider/network queries;
they must not be presented as full-app latency. UI smoke output separately records time to the window.

```powershell
.\scripts\Measure-CatalogPerformance.ps1 -Sizes 1000,5000 -Iterations 5 -OutputPath .\dist\catalog-performance.json
```

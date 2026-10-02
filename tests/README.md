# Tests

Run `npm test` for Pester 4.10.1 and `npm run test:tooling` for Node's built-in documentation-tool
regressions. `npm run check` includes both and the repository/package gates.

Tests are organized by owning boundary: Domain, Application, Infrastructure and architecture.
`Fixtures/PackageUi.ps1` replaces provider execution/inventory in a real window. `Tooling` checks
that documentation validation catches broken files/anchors and release-tree escapes.

No automated test may install, update or remove real software. Use injected adapters and temporary
files; clean them up. Interactive smoke tests need an unlocked desktop and must not run concurrently.
See [Testing](../docs/TESTING.md) for targeted commands and the manual matrix.

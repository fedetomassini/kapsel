# Releasing Kapsel

## Release Contract

The default artifact is `dist/releases/Kapsel-<version>-windows.zip`, containing a script-based
Windows app. `npm run build:exe` is an opt-in unsigned executable build, not part of automated
publication. The executable also depends on adjacent app files.

Versions use `X.Y.Z` in `package.json` and `src/modules/Shared/ProductMetadata.psm1`. A publication
tag must be exactly `vX.Y.Z`. The Release workflow checks all three values before publishing.
The local documentation check also rejects package/metadata drift.

## Prepare

1. Choose the release scope from merged changes.
2. Update both version sources together. Update the UI release text in
   `src/modules/Presentation/WinForms/ContextView.psm1` when appropriate.
3. Move shipped `Unreleased` notes into a version/date heading in [CHANGELOG.md](../CHANGELOG.md).
4. Refresh version-specific examples and baseline notes where needed; regenerate the catalog if changed.
5. Run the complete gates and interactive checks:

```powershell
npm run check
npm run test:ui:packages
npm run build:release
```

Run real-inventory smoke when relevant. Record Windows version, provider versions, display scale,
non-admin behavior and the tested artifact in the PR/release record. Interactive UI tests are not
currently part of either GitHub workflow.

## Package Contents and Verification

The build stages:

- Root PowerShell/CMD launchers and `install.ps1`.
- `src` and `assets`.
- Root README, CATALOG, CHANGELOG, CONTRIBUTING, support/conduct and license notices.
- `docs`, directory guides, and the README screenshot under `.github/assets`.
- `package.json` and `.node-version` as tooling/version reference; npm scripts are for a source checkout.

`build.ps1` checks links in the staged docs and compares ZIP entries to staged files. It fails for
missing documentation/notices or omitted files. `.github` workflows/forms are not shipped.

Extract the ZIP to a fresh folder, preferably under a path with spaces. Open `kapsel.cmd`, verify
version/search/favorites, and inspect packaged documentation offline. Existing user preferences
should survive because they are outside the release directory. Do not substitute source-tree
testing for extracted-archive verification.

Checksums, signing and a formal clean-machine test matrix are not currently implemented;
an unsigned script ZIP does not provide publisher certification.

## Publish

Commit and merge the release preparation, then create a matching tag on the intended commit:

```powershell
git tag v1.3.0
git push origin v1.3.0
```

Replace the example with the prepared version. Do not tag an uncommitted local build. The workflow:

1. Resolves package/metadata/tag version agreement.
2. Runs syntax, Pester, catalog and documentation checks.
3. Builds the default script archive.
4. Uses GitHub CLI to create the release with generated notes or upload the archive to an existing
   release with `--clobber`.

Quality has read-only repository permissions. Release grants write permission to its publishing
job. `npm run release` only runs local checks/build; it does not publish to GitHub.

After publication, download the published archive and verify its launch/version and documentation.
Review generated notes against the changelog and make sure they describe delivered features.

## Failed Workflow or Bad Release

- Before publication: fix the source/gate failure. Do not bypass checks or manually repair production
  package contents. If a tag is already public, prefer a new patch version rather than moving it.
- Publication-only transient failure: verify the original tag/commit and rerun the failed workflow.
  The workflow can replace an asset for the same tag; review whether the bytes should legitimately change.
- Published regression: document the affected behavior, mark the release appropriately in GitHub,
  point users to the last known-good version when safe, and prepare a new patch release with regression
  coverage. Do not silently overwrite a released artifact as the normal fix path.
- Preference-format regression: preserve user files before recovery and document forward/backward
  compatibility. An older binary may not understand a newer schema.

Review the incident and update the relevant issue or test coverage. Clean local generated
release artifacts with `npm run clean:releases` only when they are no longer needed for diagnosis.

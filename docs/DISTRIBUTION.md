# Distribution

Kapsel is distributed **from source only** while there is no code-signing certificate.

There is no executable builder, installer package, release archive or GitHub Release workflow. The
repository intentionally ships no `.exe`, `.zip`, `.msi` or checksum artifact: an unsigned executable
cannot establish publisher identity, and Windows SmartScreen or enterprise policy will still warn
about it. A script ZIP adds packaging maintenance without solving that trust problem.

## Run From a Checkout

Clone or download the repository, then run:

```powershell
.\kapsel.ps1
```

From Command Prompt or Explorer, run `kapsel.cmd`. Keep `src`, `assets` and the launchers together.
Node.js is only needed for repository checks, not for the desktop app.

To create per-user launchers on `PATH`:

```powershell
.\install.ps1 -AddToUserPath
```

The wrappers point at the checkout; they do not copy the application. See
[Configuration](CONFIGURATION.md#installing-path-wrappers).

## Versions and Tags

`package.json` and `src/modules/Shared/ProductMetadata.psm1` must carry the same `X.Y.Z` version so
local tooling and `kapsel.ps1 version` agree. Tags may still mark source snapshots, but they do not
publish binaries and `main` remains the supported source.

## When Signed Distribution Returns

Reintroduce packaging only together with a signing and verification plan:

1. Obtain a code-signing certificate and a reproducible signing process.
2. Define which files are distributed and how their checksums are verified.
3. Add automated build/sign verification and a clean-machine test matrix.
4. Restore release automation and update the guides, changelog and support policy in one change.

Until then, do not document or advertise downloadable builds.

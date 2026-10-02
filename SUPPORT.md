# Support

Start with the [User guide](docs/USER_GUIDE.md) and [Troubleshooting](docs/TROUBLESHOOTING.md).
For development setup, use [Development](docs/DEVELOPMENT.md).

## Ask for Help or Report a Bug

Use the [GitHub issue forms](https://github.com/fedetomassini/kapsel/issues/new/choose).
Choose bug report, feature request, or catalog request according to the problem.
Search existing issues first and reproduce with the latest release when possible.

Include:

- Kapsel version (`.\kapsel.ps1 version`) and source checkout or release ZIP.
- Windows version and Windows PowerShell version (`$PSVersionTable.PSVersion`).
- Selected provider and its version (`winget --version` or `choco --version`).
- Application key and package identifier, when package-related.
- Reproduction steps, expected outcome, and actual Activity result.
- Relevant stdout/stderr excerpts from `%LOCALAPPDATA%\Kapsel\Logs`, if needed.

Review logs before sharing: provider output can include usernames, filesystem paths, private
source names, and other local details. Attach only the relevant excerpt. Screenshots help with
layout issues; include display scale and window size.

Support is maintained on a best-effort basis; no response-time commitment is currently offered.

## Feature Proposals

Describe the user problem and observable outcome, and check existing issues for similar proposals.
Proposed features are not available until implemented and released.

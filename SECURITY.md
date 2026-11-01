# Security Policy

## Supported Versions

Security fixes target the latest published release. Upgrade to the newest release before reporting an
issue; older versions may not receive fixes.

## Report a Vulnerability

Use [GitHub private vulnerability reporting](https://github.com/fedetomassini/kapsel/security/advisories/new).
Do not open a public issue for an unpatched vulnerability.

Include:

- Affected Kapsel version (`.\kapsel.ps1 version`) and whether you use the release ZIP or a checkout.
- Windows and Windows PowerShell versions.
- Selected provider and its version, when relevant.
- Reproduction steps, impact, and any suggested fix.

Remove credentials, private source names, account names and personal filesystem paths from logs or
screenshots before sharing.

If private reporting is unavailable, open a minimal public issue asking the maintainer for a private
channel. Do not include exploit details in that issue.

## Scope

Kapsel renders a curated local catalog and launches installed package managers. Vulnerabilities in
winget, Chocolatey, catalog publishers or third-party installers belong to those projects unless
Kapsel's handling amplifies the issue, for example through unsafe command construction, unescaped
input or unintended local data exposure.

## Response

Reports are handled on a best-effort basis; no response-time commitment is offered. Confirmed issues
are fixed in the next release and credited unless you ask to remain anonymous.

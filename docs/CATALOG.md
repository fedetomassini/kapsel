# Catalog Maintenance

`src/applications.json` is the manually maintained source. Root [CATALOG.md](../CATALOG.md) is a
generated, category-grouped view. The domain normalizer is the executable contract; the authoring
requirements below are deliberately stricter than its legacy-compatible defaults.

## Authoring Schema

```json
{
  "sevenzip": {
    "category": "Utilities",
    "content": "7-Zip",
    "description": "File archiver",
    "link": "https://www.7-zip.org/",
    "winget": "7zip.7zip",
    "choco": "7zip",
    "foss": true
  }
}
```

| Field | Authoring requirement | Runtime normalization |
| --- | --- | --- |
| Top-level key | Unique stable app key; preserve across edits | Trimmed, non-empty, case-insensitive uniqueness after parsing |
| `content` | Non-empty product name | Missing value defaults to the key; blank names fail |
| `category` | Use an existing category unless a new one is justified | Missing/blank becomes `Uncategorized` |
| `description` | Short factual description; no marketing promises | Missing becomes an empty string |
| `link` | Official HTTPS product/project/publisher page | Empty allowed; non-empty must be an absolute HTTP/HTTPS URI |
| `winget` | Exact ID or `na` | Missing/blank/`na` becomes null |
| `choco` | Exact ID or `na` | Missing/blank/`na` becomes null |
| `foss` | Boolean supported by the actual product license | Missing defaults to false; non-boolean fails |

Non-null package IDs must match `^[A-Za-z0-9][A-Za-z0-9._+\-]*$`. Spaces, quotes and shell syntax
are rejected. A catalog entry with neither provider is representable but cannot be installed; new
entries should normally have at least one verified provider.

JSON parsing occurs before domain duplicate-key checks. Do not rely on the normalizer to catch
identical JSON property names that a parser has already collapsed; inspect source changes for
duplicate keys and duplicate provider IDs.

## Verify a Change

1. Search the existing catalog for the name, stable key and provider IDs.
2. Verify the publisher's page and the exact edition/channel (stable, beta, ESR, portable, etc.).
3. Use read-only provider commands to verify supplied identifiers:

```powershell
winget show --id 7zip.7zip --exact
choco info 7zip --limit-output
```

4. Check the product's actual license for `foss`; free-of-charge is not sufficient.
5. Keep the description concise and choose a category consistent with nearby entries.
6. Include verification evidence (command/result and date) in the PR. A missing provider uses `na`,
   not an unverified guess.
7. Regenerate and verify:

```powershell
npm run docs:catalog
npm run docs:catalog:check
npm test
npm run docs:check
```

Never install software just to run automated catalog tests. Provider lookups may need network and
source agreement setup, so their live availability is not part of the offline test gate.

## Key and Category Changes

Stable keys preserve selection and favorites. Renaming a key can detach user preferences even if
the product name is unchanged. Retain the key for ordinary metadata corrections. If removal or a
real product split is needed, explain the impact and any migration in the PR/changelog.

Category changes alter navigation and generated sections; propose broad reorganizations before
editing. Product/channel variants must be intentional and clearly named, not accidental duplicates.

## Generated Documentation

`scripts/Generate-CatalogMarkdown.ps1` reads through the same catalog repository/service as the app,
sorts category/app names, escapes table cells and writes UTF-8 Markdown. `-Check` compares against
the expected output without modifying it. Custom `-OutputPath` is available for inspection; the
committed default is root `CATALOG.md`.

## Scheduled Health Audit

`npm run catalog:health` probes every official link, winget identifier and Chocolatey identifier
without installing software or editing the catalog. It uses bounded concurrency and a per-request
timeout, and writes a JSON report with the catalog SHA-256, runtime and per-entry outcomes.

```powershell
npm run catalog:health -- -TimeoutSeconds 15 -MaxConcurrency 8 -OutputPath .\dist\catalog-health.json
```

The scheduled **Catalog health** workflow runs weekly and on manual dispatch. It uploads the report
and opens or updates one issue when an entry returns a definite 404/410. It closes that issue when a
later audit is clean. The catalog is never changed automatically.

Outcomes are deliberately conservative:

| Outcome | Meaning |
| --- | --- |
| `Ok` | The link or provider lookup returned a successful response. |
| `Broken` | A definite 404/410 link or provider miss; verify the identifier before editing. |
| `Inconclusive` | Timeout, DNS/TLS failure, 401/403/429, 5xx or another response that does not prove removal. |
| `Skipped` | The entry has no value for that field or the probe was disabled. |

winget lookups use the public `microsoft/winget-pkgs` manifest tree. The workflow passes
`GITHUB_TOKEN` to avoid the unauthenticated rate limit. A local run without it may report many
inconclusive winget results; that is a rate limit, not evidence that the catalog is stale. Chocolatey
lookups use the public package feed. Network failures never justify deleting a catalog entry.

Provider identifiers and official links can become stale independently of Kapsel releases. Verify
them when reviewing catalog changes and use the audit report as a starting point, not as automatic
proof that an application or package should be removed.

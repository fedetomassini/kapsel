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

Provider identifiers and official links can become stale independently of Kapsel releases. Verify
them when reviewing catalog changes; scheduled live audits are not currently implemented.

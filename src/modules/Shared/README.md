# Shared Product Metadata

`ProductMetadata.psm1` provides the product name, version, creator and description to the entry point
and UI. Keep its version equal to `package.json`; `npm run docs:check` enforces this agreement.

This directory is not a generic utility layer. Add shared code only for a concrete stable contract
used by multiple entry points. See [Distribution](../../../docs/DISTRIBUTION.md).

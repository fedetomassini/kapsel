# Shared Product Metadata

`ProductMetadata.psm1` provides the product name, version, creator and description to the entry point,
UI, build and release workflow. Keep its version equal to `package.json`; `npm run docs:check` and
tag publication enforce this agreement.

This directory is not a generic utility layer. Add shared code only for a concrete stable contract
used by multiple entry points. See [Releasing](../../../docs/RELEASING.md).

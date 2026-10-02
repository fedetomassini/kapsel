# Pull Request

## Summary

Describe the user-visible outcome and why the change is needed.

## Scope

- [ ] Bug fix
- [ ] Feature
- [ ] Interface
- [ ] Catalog
- [ ] Architecture or refactor
- [ ] Documentation
- [ ] Build or release

## Architecture

Identify the owning layer and explain any dependency-boundary change. Use `Not applicable` for a
catalog-only or documentation-only pull request.

## Validation

- [ ] `npm run validate`
- [ ] `npm test`
- [ ] `npm run test:tooling`
- [ ] `npm run docs:check`
- [ ] `npm run docs:catalog:check`
- [ ] `npm run build:check`
- [ ] UI smoke test, when presentation changed
- [ ] Full release build, when packaging changed

## Catalog Checklist

Complete for catalog changes:

- [ ] Official link verified
- [ ] Exact winget identifier verified or set to `na`
- [ ] Exact Chocolatey identifier verified or set to `na`
- [ ] FOSS value verified
- [ ] Duplicate key and application check completed

## Screenshots

Include before/after screenshots for interface changes.

## Documentation

List updated documents or explain why no documentation change is required.

## Acceptance and Compatibility

Describe acceptance evidence. Note any impact
on stable catalog keys, preferences/schema versions, provider contracts, or packaged files.

## Related Issue

Closes #

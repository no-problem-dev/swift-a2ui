# Changelog

## [Unreleased]

## [0.26.0] - 2026-08-11

### Changed

- Raised the swift-llm-client pin to 4.0.0 and the swift-structured-data pin to 3.0.0. Neither
  changes this package's own API: llm-client 4.0.0 alters protocol *requirement* signatures, which
  affects types that conform to them, not code that calls them.


### Removed

- `@_exported import` of external dependencies. `StructuredDataCore`, `JSONParsing`, and the
  A2A and AG-UI modules are no longer re-exported; code that picked them up transitively now
  has to import them explicitly. Re-exporting had made those modules part of this package's
  own public surface, which forced a break here every time one of them released a major.

### Changed

- Raised dependency pins: `swift-design-system` to 3.0.0, `swift-markdown-view` to 5.0.0,
  `swift-agui` to 0.2.0.
- Documentation is English throughout — doc comments, DocC catalogs, and this file.
- Added `.spi.yml` so Swift Package Index hosts the DocC documentation, and `CONTRIBUTING.md`
  describing how to build, test, and cut a release.
- CI no longer builds or tests; it turns a tag into a GitHub Release. Verification happens
  locally before a pull request.

## [0.25.0] - 2026-08-06

See [GitHub Releases](../../releases) for changes up to and including this version.

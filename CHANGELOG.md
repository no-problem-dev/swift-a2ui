# Changelog

## [Unreleased]

### Removed

- **BREAKING** — `FunctionSchema` types `returnType` and `callableFrom` as their enums instead of
  `String`, so a typo like `"bolean"` no longer compiles, ships, and reaches the model as fact.
  `A2UICatalog` gained `functions`, defaulting to empty — the spec's safe reading, where an
  unregistered function is refused.
- `A2UIToolConstants.errorKey` and `ComponentTreeResolver.TreeError.orphanedComponents` are gone.
  The first named a key this package never writes; the second reported a larger payload as a broken
  one.

### Fixed

- **A crash reachable from agent-supplied data.** `Double("nan")` and `Double("1e400")` parse, and
  four sites then called `Int(…)` unguarded, so a data-model string of `"nan"` bound to an index,
  a length bound or a decimal count trapped inside rendering and took the host app with it.
  `1e300` trapped too — it parses finite, so guarding finiteness alone was not enough. There is now
  one `Double`-to-`Int` conversion in the package and four call sites use it.
- **`weight: 2` and `weight: 1` laid out 50/50.** Ideal sizes were measured at the full available
  width, so every `Column` and `List` reported the whole row and the weight arithmetic received
  nothing to distribute. A weighted child is now sized out of what the unweighted children leave.
- **Repairs to imperfect model output changed what the document said.** Smart-quote folding ran
  across string values, so `don't` was rewritten and a `"` inside a value ended the string early;
  trailing-comma stripping was not string-aware, so a label containing `, }` silently lost its
  comma and still decoded. The sanitizer is one string-aware scanner now — the repairs salvage
  exactly as much as before, without altering content.
- **A version this package does not speak is no longer relabelled as one it does.** Restamping the
  sender's version erased the only evidence of an incompatibility.
- **Parse failures were reported as "no messages".** A caller could not tell an agent that sent
  nothing from an agent whose output could not be read, and those call for opposite responses. A
  partial decode now reports both what was salvaged and what was lost.
- **The prompt advertised components the tool then refused.** One unparseable schema discarded both
  allowlists. And a missing bundled resource returned `"{}"`, which tells the model the protocol has
  no messages at all — it now traps, because that is the package's own bundle and no host can
  recover from it.
- **`callFunction` was never permission-checked.** `callableFrom` never travels on the wire, and the
  processor dropped every call with a bare `break`, so the agent got neither the effect nor the
  refusal it is owed. The boundary is wired to the catalog now.
- **A function-backed picker never read as selected**, so the first tap discarded whatever the
  function returned.
- Shipped renderer labels are localized (English source, Japanese translation), and the presenter
  agent's default language is English. Its few-shot example was entirely Japanese, so a host asking
  for English was showing the model a Japanese example to imitate — and the example wins.


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

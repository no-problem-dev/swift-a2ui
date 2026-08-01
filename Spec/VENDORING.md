# Vendored A2UI specification

`Spec/<version>/` is a **verbatim copy** of the upstream specification. It is the source
of truth this library is checked against — nothing here is hand-edited, including
upstream mistakes.

| | |
|---|---|
| Upstream | https://github.com/a2ui-project/a2ui |
| Path | `specification/v1_0` |
| Commit | `2276f8cc702eaeac25ffb05be85797b2a1205c74` |
| Excluded | `eval/` (TypeScript evaluation harness; not used by the Swift implementation) |

## Copy invariant

The same schema files exist in three places and MUST stay byte-identical:

```
Spec/v1_0/json/agent_to_renderer.json
Sources/A2UIPrompt/Resources/agent_to_renderer.json   ← shipped to the LLM
Tests/A2UICoreTests/Fixtures/agent_to_renderer.json   ← conformance tests
```

Same for `common_types.json`, and for the basic catalog (`Spec/v1_0/catalogs/basic/catalog.json`
→ `Tests/A2UICatalogTests/Fixtures/{catalog,official_basic_catalog}.json`) and its 36
numbered examples. Verified by `Tests/A2UICoreTests/VendoredSpecIntegrityTests.swift`.

Updating the spec means re-copying all of them together, never editing one in place.

## Known upstream deviations

Recorded here rather than patched, so the vendored copy stays a faithful mirror.

- **Dangling `catalog.json` references.** `json/agent_to_renderer.json` refs
  `catalog.json#/$defs/anyComponent` and `json/common_types.json` refs
  `catalog.json#/$defs/anyFunction`, but v1.0 ships the file as `catalog_definition.json`
  and `https://a2ui.org/specification/v1_0/catalog.json` returns 404. Harmless here:
  `A2UIPrompt` embeds these schemas as prompt text and never resolves `$ref`.

## Version note

v1.0 was called **v0.10** while in draft — upstream's `Spec/v1_0/README.md` says so
directly. There is no separate v0.10 release; `https://a2ui.org/specification/v0_10/`
returns 404. Treat any lingering "v0.10" reference as meaning v1.0.

# ``A2UIPromptCompact``

A prompt builder for apps whose catalog exposes no client functions: it strips the `FunctionCall` types out of the schema so the model stops reaching for a call form the app cannot honour.

> **Unofficial.** Not affiliated with or endorsed by the authors of the A2UI protocol. Conforming to the specification is not a goal of this project.

## Overview

Omitting `functions` from a catalog is not enough to stop a model from emitting a function call. The `Dynamic*` types in the shared `common_types.json` still offer a `FunctionCall` branch, the model reads the branch in the schema block, and it writes one. ``CommonTypesCompactor`` removes the possibility rather than discouraging it: it deletes the `FunctionCall` and `DynamicValue` definitions and the branches inside each `Dynamic*` type's `oneOf` that reference them. Reachability pruning in `A2UIPrompt` then removes whatever those deletions left unreachable, so the saving compounds beyond the two definitions actually named.

``A2UIPromptCompactBuilder`` wraps `A2UIPromptBuilder` with that compacted schema already in place, and mirrors its public API — same `buildSystemPrompt` signature, same `schemaBlock()`, same component and message allowlists — so the two are interchangeable at the call site. The compaction itself is done once per process and shared, since it re-parses and re-serializes the bundled schema. The `builder` property is an escape hatch for APIs that take an `A2UIPromptBuilder` directly.

This is an unofficial optimization, and it is only correct for a catalog that declares `functions: []`. Parts of the A2UI specification assume a catalog that carries functions; hand this builder a catalog that declares some and the prompt will describe a schema in which the values needed to invoke them no longer exist. If the bundled schema cannot be parsed, compaction returns it unchanged — the prompt degrades to the full version rather than to an empty schema block, but nothing reports that it happened.

```swift
import A2UIPromptCompact
import A2UICatalog
import A2UITyped

// Build a system prompt with the compact builder
let builder = A2UIPromptCompactBuilder(
    allowedComponents: BasicComponent.componentNames,
    allowedMessages: nil
)
let compactPrompt = builder.buildSystemPrompt(
    role: "You are an A2UI agent.",
    workflowRules: "",
    uiDescription: "",
    includeSchema: true
)
```

## Topics

### Building a prompt

- ``A2UIPromptCompactBuilder``

### Reshaping the common types

- ``CommonTypesCompactor``

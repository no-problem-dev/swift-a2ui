# ``A2UIPrompt``

The system prompt that teaches a language model to speak A2UI: role, workflow rules, a pruned JSON schema, and a worked example, assembled into one string.

> **Unofficial.** Not affiliated with or endorsed by the authors of the A2UI protocol. Conforming to the specification is not a goal of this project.

## Overview

``A2UIPromptBuilder`` is the entry point. Give it a role description and it emits the four sections the official Python SDK emits, in the official order — the role, `## Workflow Description:`, an optional `## UI Description:`, and the JSON schema block — with a few-shot example appended last, after the schema the example has to satisfy. `buildSystemPrompt(role:workflowRules:uiDescription:examples:includeSchema:)` returns the whole string; `schemaBlock()` returns just the schema section for a prompt assembled elsewhere.

The schema block is the expensive part of the prompt, so ``SchemaPruner`` cuts it down before ``SchemaBlockFormatter`` lays it out. Two details of the pruning are easy to get wrong. First, an allowlist of `nil` skips its stage entirely while an **empty** allowlist is a no-op that keeps everything — an empty set is not a way to prune down to nothing. Second, common-types reachability always runs, and it runs *after* the component and message allowlists are applied, so the definitions that survive are the ones the narrowed schemas still reference. Whatever allowlist you pass here should be the same set the tool that receives the model's payload validates against; if the two diverge, the prompt advertises components that are then rejected.

A JSON schema can describe the shape of a message but not the rules for producing a good one, so ``A2UIWorkflowRules`` supplies those as prose. Pick one delivery rule — `default` for A2UI JSON written into the text response inside `<a2ui-json>` tags, or `toolCall` when the model sends UI through a tool — then append the topic rules that apply. `scopeRules` is the one most worth reading: nothing in the schema says that a path without a leading slash inside an instantiated template resolves relative to the array element, so without that prose a model writes absolute paths and the bindings silently resolve to nothing.

``A2UIExample`` builds the worked examples out of typed components rather than hand-written JSON strings, because the model copies whatever the example does — a wrong `version` or a property that does not exist becomes UI the client cannot render. Keep the example and the pruning in step: `A2UIPromptBuilder.presenter()` and `A2UIExample.presenterSurface()` are built from the same subset for exactly that reason. ``A2UIExampleFormatter`` wraps examples in the `---BEGIN name---` markers that prompt text refers to them by.

```swift
import A2UIPrompt
import A2UICatalog

// Build a prompt narrowed to a custom component set
let builder = A2UIPromptBuilder(
    agentToRendererSchema: nil,
    commonTypesSchema: nil,
    catalogSchema: nil,
    allowedComponents: ["Text", "Button", "Column"],
    allowedMessages: ["CreateSurfaceMessage", "UpdateDataModelMessage"]
)
let prompt = builder.buildSystemPrompt(
    role: "You are an A2UI agent.",
    workflowRules: A2UIWorkflowRules.toolCall,
    uiDescription: "Use a column as the root.",
    includeSchema: true
)
```

## Topics

### Building a prompt

- ``A2UIPromptBuilder``

### Rules the schema cannot express

- ``A2UIWorkflowRules``

### Worked examples

- ``A2UIExample``
- ``A2UIExampleFormatter``

### Assembling the schema block

- ``SchemaPruner``
- ``SchemaBlockFormatter``

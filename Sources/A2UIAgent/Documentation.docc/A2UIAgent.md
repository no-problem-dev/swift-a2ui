# ``A2UIAgent``

Everything a presenter-style A2UI agent says about itself: its role, its tools, and its protocol declaration.

> **Unofficial.** Not affiliated with or endorsed by the authors of the A2UI protocol. Conforming to the specification is not a goal of this project.

## Overview

`A2UIAgent` gathers into one module all the knowledge needed to run an A2UI presenter (content-presenting) agent. It is the Swift counterpart of the Python SDK's `a2ui.adk` module and of the upstream rizzcharts reference agent.

The `A2UIPresenterAgent` namespace exposes the whole module. `systemPrompt(language:)` composes the role definition, the UI contract, and the workflow rules into a complete system prompt. `tools(components:)` returns a `SendA2UIToClientTool` narrowed to an allowed component set; that same set both prunes the schema shown to the model and validates what the model produces, so a component the model was never offered comes back as a tool error instead of reaching the renderer. The schema and the worked examples belong to the tool and travel into the system prompt when it is attached, as in the upstream reference agent. `agentExtension()` returns the A2UI support declaration to embed in the A2A agent card.

A host app only injects these into its executor and keeps no UI knowledge of its own. Language, model, and component palette are the choices left to the host — and a palette persisted from an older catalog can be passed straight through, because `sanitizedComponents(_:)` drops names the catalog no longer knows and falls back to the default nine components when nothing is left.

One constraint is easy to miss: the presenter maintains a *single* surface for a conversation and updates it in place every turn. `defaultDescription` and `hostOutputConstraint(agentName:)` exist so that an orchestrator reads the agent that way rather than as a one-shot final step.

```swift
import A2UIAgent

// Injecting into an executor
let systemPrompt = A2UIPresenterAgent.systemPrompt(language: "Japanese")
let tools = A2UIPresenterAgent.tools(
    components: A2UIPresenterAgent.defaultComponents
)
let ext = A2UIPresenterAgent.agentExtension()

// Adding the host output constraint
let constraint = A2UIPresenterAgent.hostOutputConstraint(agentName: "a2ui")
```

## Topics

### Agent self-description

- ``A2UIPresenterAgent``

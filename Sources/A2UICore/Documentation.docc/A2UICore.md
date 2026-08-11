# ``A2UICore``

The A2UI wire format as Swift value types: every message that passes between an agent and a client, plus the dynamic values a component is built from.

> **Unofficial.** Not affiliated with or endorsed by the authors of the A2UI protocol. Conforming to the specification is not a goal of this project.

## Overview

`A2UICore` is the floor the rest of `swift-a2ui` stands on. It owns the message types and nothing else — no SwiftUI, no LLM client, no business logic — so it can be imported from any layer of an application, including one that only wants to encode a message and hand it to its own transport.

Traffic runs in two directions and each has its own envelope. ``AgentMessage`` covers what an agent sends: create a surface, update its components, update its data model, delete it, call a function on the client, answer an action. ``RendererMessage`` covers what comes back: a user action, a function result, an error. The two are asymmetric on purpose — decoding an ``AgentMessage`` tolerates a missing `version` because a language model wrote it and losing the whole turn over a misplaced key costs a full regeneration, while a ``RendererMessage`` is written by code and must carry one.

Components stay untyped here. ``UpdateComponents`` carries `StructuredValue`, and turning that into a concrete `Button` or `Row` is the catalog's job, which is what keeps this module catalog-agnostic. What the module does define is how a component's properties can be expressed: ``DynamicString``, ``DynamicBoolean``, ``DynamicNumber``, ``DynamicStringList``, and ``DynamicValue`` each hold either a literal, a ``DataBinding`` into the surface's data model, or a ``FunctionCall``.

The one thing a new reader tends to look for and not find is permission metadata on the wire. A ``FunctionCall`` carries no `callableFrom` and no `returnType`: both live on the catalog's function definition, so a renderer must look the name up itself before running anything an agent asked for. ``FunctionBoundary`` implements that check and produces the `INVALID_FUNCTION_CALL` error the specification requires.

```swift
import A2UICore

// The first message an agent sends to a client
let create = AgentMessage.createSurface(CreateSurface(
    surfaceId: "main",
    catalogId: "https://a2ui.org/specification/v1_0/catalogs/basic/catalog.json"
))

// A user action arriving from the client
let action = RendererMessage.action(UserAction(
    name: "submit",
    surfaceId: "main",
    sourceComponentId: "submit-button",
    timestamp: "2026-01-01T00:00:00Z",
    context: [:]
))
```

## Topics

### Messages the agent sends

- ``AgentMessage``
- ``CreateSurface``
- ``UpdateComponents``
- ``UpdateDataModel``
- ``DeleteSurface``
- ``CallFunctionMessage``
- ``ActionResponseMessage``
- ``ActionResponse``
- ``CallId``

### Messages the client sends back

- ``RendererMessage``
- ``UserAction``
- ``FunctionResponse``
- ``RendererError``

### Components

- ``A2UIComponentProtocol``
- ``ComponentId``
- ``AccessibilityAttributes``
- ``CheckRule``

### Dynamic values

- ``DynamicString``
- ``DynamicBoolean``
- ``DynamicNumber``
- ``DynamicStringList``
- ``DynamicValue``
- ``DataBinding``
- ``ChildList``

### Actions and functions

- ``Action``
- ``EventAction``
- ``FunctionCall``
- ``CallableFrom``
- ``FunctionReturnType``

### Conformance rules

- ``CatalogIdentifier``
- ``FunctionBoundary``

### Version and tool constants

- ``A2UIVersion``
- ``A2UIToolConstants``

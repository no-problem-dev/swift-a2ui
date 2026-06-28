---
title: swift-a2ui README
created: 2026-06-27
tags: [a2ui, swift, spm, llm, ui-protocol]
status: active
---

English | [日本語](./README.ja.md)

# swift-a2ui

> A complete Swift implementation of the Google A2UI protocol — a type-safe library suite for LLM agents to render rich UI on the client

## Overview

`swift-a2ui` is a Swift implementation of the [A2UI (Agent-to-UI) protocol](https://a2ui.org). It provides a compile-time type-safe Swift API through which an LLM agent can declaratively create, update, and delete UI surfaces on the client via JSON messages, and receive user actions back with responses.

### Key Features

- **Full A2UI v0.10 support**: All message types implemented — `createSurface` / `updateComponents` / `updateDataModel` / `callFunction` / `actionResponse`
- **Type-safe catalog**: LLM-facing JSON Schema generated from Swift types as the single source of truth (schema drift detected at compile time)
- **Zero-`AnyView` generic renderer**: `A2UISurfaceView<Catalog>` with the catalog as a type parameter renders to SwiftUI without type erasure
- **Faithful conformance to the official protocol**: Module structure mirrors the Python SDK (`a2ui.adk` / `a2ui.a2a`) design
- **Multi-agent support**: A2A protocol integration and surface-ownership ledger for orchestration

---

## Module Structure

13 modules organized into 5 groups by role.

### Group 1 — Core Protocol Layer

The lowest layer: defines the A2UI wire format (JSON) as Swift types. No SwiftUI or LLM-client dependencies.

| Module | Role |
|--------|------|
| **A2UICore** | `ServerMessage` / `ClientMessage` enums; individual message types (`CreateSurface`, `UpdateComponents`, `UpdateDataModel`, etc.); `UserAction`; `DataBinding`; bindable value types (`DynamicString` / `DynamicBoolean` / `DynamicNumber`) |

**Key types:**

```swift
// Server → Client
public enum ServerMessage: Sendable, Equatable, Codable {
    case createSurface(CreateSurface)
    case updateComponents(UpdateComponents)
    case updateDataModel(UpdateDataModel)
    case deleteSurface(DeleteSurface)
    case callFunction(CallFunctionMessage)
    case actionResponse(ActionResponseMessage)
}

// Client → Server
public enum ClientMessage: Sendable, Equatable, Codable {
    case action(UserAction)
    case error(ClientError)
    case functionResponse(FunctionResponse)
}
```

---

### Group 2 — Component Catalog

Defines the component palette available to the LLM as Swift types and auto-generates the LLM-facing JSON Schema from those type definitions.

| Module | Role |
|--------|------|
| **A2UICatalog** | Swift type definitions for 18 components; `ComponentCatalog` protocol; type-driven schema generation via `ComponentSchema` / `SchemaRenderer`; category enums (`display` / `layout` / `input`) |

**Built-in components (`BasicComponentCatalog`):**

| Category | Components |
|----------|-----------|
| Display | `Text`, `Image`, `Icon`, `Video`, `AudioPlayer` |
| Layout | `Row`, `Column`, `List`, `Card`, `Tabs`, `Modal`, `Divider` |
| Input | `Button`, `TextField`, `CheckBox`, `ChoicePicker`, `Slider`, `DateTimeInput` |

The schema is generated from Swift types, so implementation and schema cannot diverge:

```swift
// Schema generation
let schema: String = BasicComponentCatalog.catalogSchemaJSON()

// Catalog ID
let id: String = BasicComponentCatalog.catalogId
// → "https://a2ui.org/specification/v0_10/catalogs/basic/catalog.json"
```

---

### Group 3 — LLM Prompt & Parser

Assembles system prompts for agents and extracts A2UI messages from LLM output.

| Module | Role |
|--------|------|
| **A2UIPrompt** | `A2UIPromptBuilder` — builds system prompts (role / workflow rules / UI description / schema block); catalog and message-type pruning via allowlists. `A2UIExample` — reference surface examples generated from typed components |
| **A2UIPromptCompact** | `A2UIPromptCompactBuilder` — lightweight variant that strips `FunctionCall` types from `common_types` for apps that don't use functions |
| **A2UIParser** | `A2UIStreamingParser` — incremental extraction of `<a2ui-json>` blocks from streaming LLM output. `A2UIPayloadFixer` — auto-corrects common JSON malformations from LLM generation. `JSONSanitizer` |

**Building a prompt:**

```swift
// Standard builder (all catalog components and message types)
let builder = A2UIPromptBuilder()
let prompt = builder.buildSystemPrompt(
    role: "You are a helpful assistant that renders UI.",
    uiDescription: "Show a card with a title and a confirm button."
)

// Presenter preset (9 components + 3 messages for content-presentation agents)
let presenterBuilder = A2UIPromptBuilder.presenter()

// Custom pruning
let builder = A2UIPromptBuilder(
    serverToClientSchema: nil,
    commonTypesSchema: nil,
    catalogSchema: nil,
    allowedComponents: ["Text", "Column", "Row", "Button", "Image"],
    allowedMessages: ["CreateSurfaceMessage", "UpdateComponentsMessage"]
)
```

**Using the streaming parser:**

```swift
let parser = A2UIStreamingParser()
let processor = TypedMessageProcessor<BasicCatalog>()

for chunk in llmStream {
    let parts = parser.feed(chunk)
    for part in parts {
        if let messages = part.messages {
            // Apply the [ServerMessage] array to the rendering layer
            processor.process(messages)
        }
        if let text = part.text {
            // Plain text portion
            print(text)
        }
    }
}
let finalParts = parser.finalize()
```

---

### Group 4 — Surface State / Renderer

Manages client-side surface state and SwiftUI rendering.

| Module | Role |
|--------|------|
| **A2UISurface** | `DataModel` — JSON Pointer read/write with reactive path subscriptions (Bubble & Cascade notifications). `ComponentValidator`, template expansion (`ChildList`) |
| **A2UIRuntime** | `DataContext` — scoped binding resolution. `TemplateExpander` — expands `{componentId, path}` templates with collection scopes |
| **A2UITyped** | `A2UICatalog` protocol (`associatedtype Node: ComponentNode`); type-safe catalog composition via `CombinedNode<Primary, Fallback>`; `BasicCatalog` (exposes `BasicComponent` as `ComponentNode`); `A2UIValidation` |
| **A2UITypedRenderer** | `RenderableCatalog` protocol; `A2UISurfaceView<Catalog>` (SwiftUI View); `NodeView<Catalog>`; `RenderContext<Catalog>` (two-way bindings / checks evaluation / child rendering context) |

**Using `A2UISurfaceView`:**

```swift
import SwiftUI
import A2UITypedRenderer

// 1. Create a surface (@Observable, so it can be held in @State)
@State var surface = TypedSurface<BasicCatalog>(rootId: "root", nodes: [])

// 2. Handler to apply server messages
func apply(_ message: ServerMessage) {
    switch message {
    case .updateComponents(let msg):
        guard let nodes = try? TypedSurface<BasicCatalog>.decodeNodes(
            fromJSONArray: JSONEncoder().encode(msg.components)
        ) else { return }
        surface.applyUpdateComponents(nodes)
    case .updateDataModel(let msg):
        surface.applyUpdateDataModel(path: msg.path ?? "", value: msg.value)
    default:
        break
    }
}

// 3. Embed in SwiftUI
var body: some View {
    A2UISurfaceView(surface, busy: isGenerating)
}
```

**Composing a custom catalog:**

```swift
// Layer your own components on top of BasicCatalog
enum AppCatalog: A2UICatalog {
    typealias Node = CombinedNode<MyNode, BasicComponent>
    static let catalogId = "com.example.my-app"
}

// BasicEmbeddingNode conformance re-uses the BasicCatalog renderer
extension MyNode: BasicEmbeddingNode { ... }
```

---

### Group 5 — Agent Integration / Orchestration

Provides A2UI tools to LLM agents and supports multi-agent configurations.

| Module | Role |
|--------|------|
| **A2UIAgentTool** | `SendA2UIToClientTool<Catalog>` — the official `send_a2ui_json_to_client` tool pattern. Parses, auto-corrects, and validates JSON (allowlist conformance), then returns `validated_a2ui_json`. `A2UIToolResultExtractor` — extracts `[ServerMessage]` from tool results |
| **A2UIAgent** | `A2UIPresenterAgent` — self-describing package for presenter (content-display) agents. Provides `systemPrompt()` / `tools()` / `agentExtension()` / `hostOutputConstraint()`. Hosts inject these; all UI knowledge is encapsulated in this module |
| **A2UIA2A** | A2A protocol integration. `Part.a2ui(_:)` wraps A2UI messages as `application/a2ui+json` data parts. `A2UIExtension` — declares the A2UI protocol on an agent card. `A2UIClientCapabilities` / `A2UIClientDataModel` / `A2UIMessageMetadata` |
| **A2UIOrchestration** | `SurfaceOwnership` — surface-ownership ledger (which agent owns which surface). Deterministic `UserAction` routing via `owner(ofUserActionIn:)`. Data-model stripping via `outboundMetadata(_:capabilities:for:)` (prevents data leakage between agents) |

**Injecting `A2UIPresenterAgent`:**

```swift
import A2UIAgent
import A2ACore
import LLMClient

// The library owns everything the presenter agent needs
let agentName = A2UIPresenterAgent.defaultName

// 1. System prompt
let systemPrompt = A2UIPresenterAgent.systemPrompt(language: "Japanese")

// 2. Tools (catalog palette is customizable)
let tools = A2UIPresenterAgent.tools(
    components: ["Column", "Row", "Text", "Image", "Icon", "List", "Card", "Button", "Divider"]
)

// 3. Declare in the A2A card extensions
let agentExtension = A2UIPresenterAgent.agentExtension()

// 4. Constraint injected into the orchestrator's system prompt
let constraint = A2UIPresenterAgent.hostOutputConstraint(agentName: agentName)
```

**Orchestration (`SurfaceOwnership`):**

```swift
import A2UIOrchestration

var ownership = SurfaceOwnership()

// Record ownership each time a sub-agent responds
ownership.record(surfacesCreatedIn: responseparts, by: "a2ui")

// Route UserActions (no LLM call needed)
if let agent = ownership.owner(ofUserActionIn: incomingParts) {
    // Forward directly to the target agent
    await router.send(to: agent, parts: incomingParts)
}

// Strip data model to only the agent's owned surfaces before sending
let metadata = try ownership.outboundMetadata(
    baseMetadata,
    capabilities: clientCapabilities,
    for: "a2ui"
)
```

---

## Installation

### Swift Package Manager

Add to your `Package.swift` `dependencies`:

```swift
.package(url: "https://github.com/no-problem-dev/swift-a2ui.git", from: "0.0.1"),
```

List the modules you need in your target's `dependencies`:

```swift
.target(
    name: "MyApp",
    dependencies: [
        // Minimum (core only)
        .product(name: "A2UICore", package: "swift-a2ui"),

        // Prompt building + parser
        .product(name: "A2UIPrompt", package: "swift-a2ui"),
        .product(name: "A2UIParser", package: "swift-a2ui"),

        // SwiftUI renderer (iOS/macOS UI)
        .product(name: "A2UITypedRenderer", package: "swift-a2ui"),

        // LLM agent tool
        .product(name: "A2UIAgentTool", package: "swift-a2ui"),

        // Presenter agent self-description
        .product(name: "A2UIAgent", package: "swift-a2ui"),

        // A2A integration / orchestration
        .product(name: "A2UIA2A", package: "swift-a2ui"),
        .product(name: "A2UIOrchestration", package: "swift-a2ui"),
    ]
)
```

---

## Supported Platforms

| Platform | Minimum Version |
|----------|----------------|
| macOS | 14.0 (Sonoma) |
| iOS | 17.0 |

Swift tools version: **6.2**

---

## External Dependencies

| Package | Purpose |
|---------|---------|
| `no-problem-dev/swift-structured-data` | JSON parse / serialize (`StructuredValue`, `JSONParser`) |
| `no-problem-dev/swift-a2a` | A2A protocol core (`AgentCard`, `Part`, `StreamResponse`) |
| `no-problem-dev/swift-design-system` | SwiftUI design tokens (color / spacing / motion / Glass Card) |
| `no-problem-dev/swift-markdown-view` | Markdown rendering in the `Text` component |
| `no-problem-dev/swift-llm-client` | `Tool` / `TurnEndingTool` protocols (base for `SendA2UIToClientTool`) |

---

## License

See [LICENSE](./LICENSE).

---

Last updated: 2026-06-27

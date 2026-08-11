English | [日本語](./README.ja.md)

# swift-a2ui

Lets an LLM agent answer with a real SwiftUI screen — cards, forms, buttons the user can tap — instead of a wall of text, and keeps the model to the components your app can actually draw.

> **Unofficial.** Not affiliated with or endorsed by the authors of the A2UI protocol. Conforming to the specification is not a goal of this project.

## Overview

Under [A2UI](https://a2ui.org), the agent sends JSON messages that create, update, and delete UI
surfaces, and the client renders them and sends user actions back. This package is both halves
in Swift.

- **The palette is Swift types.** The JSON Schema the model is prompted with is generated from
  them, so what the model is told it may draw cannot drift from what the renderer knows how to
  draw.
- **Prompting and validation share one allowlist.** Offer six components and the model gets a
  schema for six; anything else is rejected by the tool with an error it corrects from in the
  same turn, so the user never sees an unsupported-component placeholder.
- **No `AnyView`, no string matching.** `A2UISurfaceView<Catalog>` is generic over the catalog,
  so adding your own components is a type-level extension the compiler checks for exhaustiveness.
- **Model output is messy; this expects that.** Streaming text is parsed incrementally as it
  arrives, and the common malformations LLMs produce are repaired rather than dropped.
- **More than one agent can share a screen.** An ownership ledger routes each user action back
  to the agent that drew the surface, and keeps one agent's data model out of another's messages.

## Usage

Render whatever the agent sends. `TypedMessageProcessor` holds the surfaces and
`A2UISurfaceView` draws them:

```swift
import SwiftUI
import A2UIParser
import A2UITyped
import A2UITypedRenderer

struct AgentReply: View {
    @State private var processor = TypedMessageProcessor<BasicCatalog>()
    private let parser = A2UIStreamingParser()

    var body: some View {
        ForEach(processor.ordered) { surface in
            A2UISurfaceView(surface)
        }
    }

    func receive(_ chunk: String) {
        for part in parser.feed(chunk) {
            if let messages = part.messages {
                processor.process(messages)
            }
        }
    }
}
```

On the agent side, `A2UIPresenterAgent` carries its own prompt, tool, and agent-card extension,
so the host picks only the language and the palette:

```swift
import A2UIAgent

let prompt = A2UIPresenterAgent.systemPrompt(language: "English")
let tools = A2UIPresenterAgent.tools(
    components: ["Column", "Row", "Text", "Image", "Card", "Button"]
)
```

## Documentation

[API reference for every module](https://no-problem-dev.github.io/swift-a2ui/documentation/a2uicore/),
including how to compose a catalog of your own components.

## Installation

Add the package to your `Package.swift`:

```swift
.package(url: "https://github.com/no-problem-dev/swift-a2ui.git", .upToNextMinor(from: "0.26.0")),
```

Each module ships as its own library, so depend only on what you use — `A2UICore` for the
message types, `A2UITypedRenderer` to draw them, `A2UIAgent` for the ready-made presenter agent:

```swift
.target(name: "MyApp", dependencies: [
    .product(name: "A2UICore", package: "swift-a2ui"),
    .product(name: "A2UITypedRenderer", package: "swift-a2ui"),
    .product(name: "A2UIAgent", package: "swift-a2ui"),
])
```

## Requirements

| | |
|---|---|
| Swift | 6.2 |
| Platforms | iOS 17 · macOS 14 |

## Contributing

Bug reports and pull requests are welcome — see [CONTRIBUTING.md](./CONTRIBUTING.md).

## License

MIT. See [LICENSE](./LICENSE).

# ``A2UITypedRenderer``

A type-safe SwiftUI renderer for `A2UICatalog` that draws a component tree without a single `AnyView`.

> **Unofficial.** Not affiliated with or endorsed by the authors of the A2UI protocol. Conforming to the specification is not a goal of this project.

## Overview

`A2UITypedRenderer` builds a zero-erasure SwiftUI renderer on top of the generic catalog types from `A2UITyped`. A generic `NodeView<Catalog>` walks the component tree recursively and turns each node into the view its catalog says it should be. The price of that is genericity: `Catalog` is a type parameter on almost everything here, and it is viral through anything that renders a child.

A catalog opts in by conforming to ``RenderableCatalog``, whose one requirement is `view(for:in:)` — a single `@ViewBuilder switch` over the node sum type. There is no string matching and no `default` case, so adding a component to a catalog fails to compile until it is drawn. ``RenderContext`` is the second argument to that function: it carries the data scope, the color palette, the URL opener, and the methods for resolving bindings, evaluating `checks`, and rendering children. Resolve values through the context rather than reading the data model directly — the resolvers are what establish the SwiftUI dependency that makes a binding update the view.

``TypedSurface`` is one surface: a flat id-to-node map plus its data model, mirroring the A2UI wire format where a parent names its children by id string. It is `@Observable` and applies the two partial updates, `updateComponents` and `updateDataModel`. ``TypedMessageProcessor`` sits above it, applying a stream of `AgentMessage` values to a keyed set of surfaces and handing user interactions back to the host as `UserAction`.

``A2UISurfaceView`` is the entry point for rendering a whole surface, including the busy state and the placeholder shown before the root component arrives. ``BasicComponentView`` draws the standard components for any catalog that embeds `BasicEmbeddingNode`, which is how a custom catalog delegates its fallback case. Media components open an in-app viewer on tap by default; call `a2uiMediaViewer(false)` to suppress that where a fullscreen cover is unwelcome.

```swift
import SwiftUI
import A2UITypedRenderer
import A2UITyped

// Hold and render a surface built on BasicCatalog.
struct ContentView: View {
    // TypedSurface is @Observable, so @State is the right home for it.
    @State private var surface = TypedSurface<BasicCatalog>(nodes: [])

    var body: some View {
        // A2UISurfaceView takes the surface as an unlabeled first argument.
        A2UISurfaceView(surface)
    }
}

// Apply server messages through the processor.
@MainActor
func apply(_ messages: [AgentMessage], to processor: TypedMessageProcessor<BasicCatalog>) {
    processor.process(messages)
}
```

## Topics

### Rendering a surface

- ``A2UISurfaceView``
- ``NodeView``
- ``BasicComponentView``

### Making a catalog renderable

- ``RenderableCatalog``
- ``RenderContext``

### Surface state

- ``TypedSurface``
- ``TypedMessageProcessor``

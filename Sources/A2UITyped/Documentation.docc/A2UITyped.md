# ``A2UITyped``

The generic catalog layer: compile-time-typed component nodes and the catalog abstraction a renderer is parameterised by.

> **Unofficial.** Not affiliated with or endorsed by the authors of the A2UI protocol. Conforming to the specification is not a goal of this project.

## Overview

`A2UITyped` replaces A2UI's stringly-typed component dispatch with a compile-time-typed design. It does not depend on SwiftUI and builds fully on macOS, so type-level work and its tests run as a plain executable rather than through a simulator.

``A2UICatalog`` declares a catalog's associated `Node` type — the ``ComponentNode`` to decode into — and the `catalogId` that identifies it on the wire. ``CatalogNode`` wraps that node type with the distinction A2UI requires a renderer to make: a `component` name the catalog does not have decodes as `.unknown(name:id:raw:)` and must degrade gracefully, while a *known* name whose properties are malformed throws — a validation error to hand back to the agent.

``BasicCatalog`` is the concrete catalog for the standard components, unified as `BasicComponent`. ``CombinedNode`` composes two node types and routes by `component` name, with `Primary` winning collisions so an application can override a standard component with its own implementation while still embedding the whole basic node as `Fallback`.

Two constraints catch new readers. ``CatalogResolution`` implements the v1.0 order for deciding which catalog interprets a component — its own `catalogId`, then the surface default, then nothing — and there is deliberately no fallback to a catalog merely declared in capabilities. And ``A2UIValidation`` runs over a whole turn of messages, aggregating components per surface across `createSurface` and `updateComponents`, so it must be given the complete turn rather than one message at a time.

```swift
import A2UITyped

// Decode a server message against BasicCatalog.
let data: Data = ... // JSON payload
let node = try JSONDecoder().decode(CatalogNode<BasicComponent>.self, from: data)
switch node {
case .known(let known):
    print("known component:", known)
case .unknown(let name, _, _):
    print("unknown component:", name)
}
```

## Topics

### Catalogs

- ``A2UICatalog``
- ``BasicCatalog``

### Component nodes

- ``ComponentNode``
- ``CatalogNode``
- ``CombinedNode``
- ``BasicEmbeddingNode``

### Resolution and validation

- ``CatalogResolution``
- ``A2UIValidation``

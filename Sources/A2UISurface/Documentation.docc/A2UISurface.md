# ``A2UISurface``

The runtime state of one A2UI surface: its component tree, its data model, and the subscriptions
that connect the two.

> **Unofficial.** Not affiliated with or endorsed by the authors of the A2UI protocol. Conforming to the specification is not a goal of this project.

## Overview

An agent describes a surface as a flat dictionary of components that refer to each other by id, plus
a separate document of application data addressed by JSON Pointer. This module holds both halves and
keeps them in step. ``ComponentTreeResolver`` walks the id references once and returns a
``ComponentNode`` tree; ``DataModel`` stores the data and hands out ``A2UISubscription`` handles for
individual paths.

``DataModel`` is a reference type and deliberately not `@Observable` — SwiftUI never observes it
directly. The binder layer subscribes to paths and republishes the results as observable props. The
notification rule is the part worth knowing before you use it: a write to a path notifies the
subscribers of that path, of every ancestor, and of every descendant. Writing `/user/name` wakes a
subscriber on `/user`, and replacing `/user` wholesale wakes a subscriber on `/user/name`. Every
`subscribe` also fires once, synchronously, before it returns.

Path resolution follows RFC 6901 with one A2UI extension implemented in ``JSONPointer``: a path that
does not begin with `/` is relative and resolves against a scope, which is how a component inside a
template instance addresses its own row. ``TypeCoercion`` converts whatever a path yields into the
type a component asked for, and it is total — an unusable value arrives as `""`, `false`, or `0`
rather than as an error, so nothing downstream sees a coercion failure.

``ComponentValidator`` is the guard to run before building a tree from an untrusted payload. It
rejects duplicate ids, a missing root, cycles, and runaway depth; it does not check that referenced
children exist, and a child id with no component behind it is dropped from the tree silently.

```swift
import A2UISurface

// Create a data model and write a value at a path
let model = DataModel()
model.set("/greeting", .string("Hello"))

// Read the path back with a JSON Pointer
let value = model.get("/greeting")   // .string("Hello")
```

## Topics

### Component tree

- ``ComponentNode``
- ``ComponentTreeResolver``

### Data model

- ``DataModel``
- ``A2UISubscription``
- ``JSONPointer``
- ``TypeCoercion``

### Validation

- ``ComponentValidator``

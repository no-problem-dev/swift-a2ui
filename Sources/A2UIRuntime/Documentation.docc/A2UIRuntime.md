# ``A2UIRuntime``

The evaluation layer of a surface: data scopes, template expansion, function evaluation, and check rules.

> **Unofficial.** Not affiliated with or endorsed by the authors of the A2UI protocol. Conforming to the specification is not a goal of this project.

## Overview

`A2UIRuntime` turns the component tree and data model held by `A2UISurface` into the concrete values a view layer draws: it expands templates, resolves bindings, evaluates built-in functions, and runs check rules. It does not depend on SwiftUI, so all of that logic is testable on its own.

``DataContext`` is the piece everything else hangs off. It is a scoped view onto a `DataModel`: the scope is a JSON Pointer path, a relative binding (`name`) resolves from it, and an absolute one (`/company`) from the root. Resolution follows the spec's coercion table, which means an undefined binding yields `""`, `false`, or `0` rather than an error — an empty label can be a wrong path, not empty text.

``TemplateExpander`` expands a `ChildList` into ``ResolvedChild`` slots. A static `ids` list keeps the parent scope; a `template(componentId, path)` iterates the collection at `path` and gives each instance the child scope `/<path>/<index>`, which is what makes relative bindings inside the template land on the right element. Each iteration also carries a zero-based `collectionIndex`, and that is the only thing that lets the built-in `@index` evaluate — outside an iteration it is an evaluation error, and the call resolves to nothing.

``FunctionResolving`` is the single hook `DataContext` uses to evaluate a `FunctionCall`, which keeps binding resolution independent of any registry. ``BasicFunctions`` implements the Basic Catalog functions (`formatString`, `required`, `formatDate`, `pluralize`, …); it defaults to the `en_US` locale, so pass your own when the output is user-facing. ``NoFunctionResolver`` is the default when nothing is injected and resolves every call to `nil`. ``ChecksEvaluator`` walks a component's `[CheckRule]` and reports the first failing message, the one the spec expects a `Button` to be disabled by.

```swift
import A2UIRuntime
import A2UISurface

// Build a data context backed by the built-in function resolver.
let resolver = BasicFunctions()
let context = DataContext(dataModel: DataModel(), functions: resolver)

// Expand a ChildList into concrete child slots.
let children = TemplateExpander.expand(listNode, in: context)
for child in children {
    print(child.componentId, child.basePath)
}
```

## Topics

### Data scopes

- ``DataContext``

### Template expansion

- ``TemplateExpander``
- ``ResolvedChild``

### Function evaluation

- ``FunctionResolving``
- ``BasicFunctions``
- ``NoFunctionResolver``

### Client-side checks

- ``ChecksEvaluator``

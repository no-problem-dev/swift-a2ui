import A2UICore

/// A catalog's **node type**: the closed sum of components that catalog can decode and render.
///
/// This is the type-safe replacement for the stringly-typed `ComponentModel.type` dispatch. A
/// renderer is generic over a catalog whose `Node: ComponentNode`, so the set of renderable
/// components is fixed and exhaustive **at compile time**, yet open to extension because the
/// consumer chooses (and composes) the concrete `Node` — the library never closes the set itself.
///
/// `componentNames` is the routing metadata that lets `CatalogNode` separate the two distinct
/// A2UI failure modes (see `CatalogNode`):
/// - a `component` name this catalog does **not** handle → spec "unknown component" → graceful fallback
/// - a name it **does** handle but with malformed props → decode throws → validation error to report
public protocol ComponentNode: Decodable, Sendable, Equatable {
    /// The wire `component` discriminators this node decodes. Built from the per-component
    /// `componentName` constants (the schema SSOT) — never string literals.
    static var componentNames: Set<String> { get }

    /// The instance id (flat id-map key and child-reference target).
    var id: ComponentId { get }

    /// The wire `component` discriminator of this concrete instance.
    var componentName: String { get }
}

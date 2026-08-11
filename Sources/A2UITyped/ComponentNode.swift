import A2UICore

/// A catalog's **node type**: the closed sum of components that catalog can decode and render.
///
/// It replaces stringly-typed `ComponentModel.type` dispatch. A renderer takes the catalog as a type
/// parameter whose `Node` conforms here, so the set of renderable components is fixed and switched
/// exhaustively at compile time, yet stays open to extension because the consumer chooses and composes
/// the concrete `Node`.
///
/// `componentNames` is the routing metadata `CatalogNode` uses to keep A2UI's two failure modes apart:
/// - a `component` name this catalog does **not** handle → the spec's "unknown component" → graceful
///   fallback
/// - a name it **does** handle but with malformed props → a decode throw → a validation error to report
public protocol ComponentNode: Decodable, Sendable, Equatable {
    /// The wire `component` discriminators this node decodes.
    ///
    /// Build it from each component's `componentName` constant — the schema's single source of truth —
    /// and never from string literals, so a renamed component cannot quietly drop out of routing and
    /// start arriving as an unknown component.
    static var componentNames: Set<String> { get }

    /// The instance id: the key in the flat id map, and what every child reference points at.
    var id: ComponentId { get }

    /// The `component` discriminator this instance serializes as; it must be one of `componentNames`.
    var componentName: String { get }

    /// The catalog this component declares itself to belong to (v1.0 `ComponentCommon.catalogId`).
    ///
    /// It overrides the surface default `catalogId`, which is what lets one surface mix catalogs. The
    /// majority of components declare nothing and return `nil`.
    var catalogId: String? { get }
}

extension ComponentNode {
    /// Declares no catalog, deferring to the surface default `catalogId`.
    public var catalogId: String? { nil }
}

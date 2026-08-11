import Foundation

/// A named set of components a surface can be built from, described to the model by one JSON
/// Schema document.
public protocol ComponentCatalog: Sendable {
    /// URI a surface or an individual component names to select this catalog; a component carrying
    /// a different `catalogId` is not resolved here.
    var catalogId: String { get }

    /// The catalog document to embed in the model's prompt, as a JSON string.
    static func catalogSchemaJSON() -> String
}

/// The catalog shipped with swift-a2ui: the standard display, layout, and input components defined
/// by A2UI v1.0.
public struct BasicComponentCatalog: ComponentCatalog, Sendable {
    /// Canonical URI of the basic catalog. A surface that names any other catalog is not served by
    /// this type.
    public static let catalogId = "https://a2ui.org/specification/v1_0/catalogs/basic/catalog.json"

    public var catalogId: String { Self.catalogId }

    public init() {}

    /// Renders the catalog schema from the Swift component types rather than from a checked-in
    /// `catalog.json`.
    ///
    /// The property declarations and the `SchemaEnumerable` enums are the single source of truth,
    /// so the schema the model is prompted with cannot drift from the types that decode its reply.
    /// `GeneratedSchemaEquivalence` checks the result against the official catalog.
    public static func catalogSchemaJSON() -> String {
        BasicCatalogSchema.render()
    }
}

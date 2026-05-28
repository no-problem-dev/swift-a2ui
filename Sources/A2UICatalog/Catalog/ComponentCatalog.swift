import Foundation

/// Protocol that all A2UI component catalogs conform to.
public protocol ComponentCatalog: Sendable {
    /// The unique identifier URI for this catalog.
    var catalogId: String { get }

    /// Return the catalog's JSON schema as a string.
    static func catalogSchemaJSON() -> String
}

/// The basic catalog bundled with swift-a2ui.
///
/// Contains standard display, layout, and input components defined in the
/// A2UI v0.9 specification.
public struct BasicComponentCatalog: ComponentCatalog, Sendable {
    /// The canonical catalog identifier URI.
    public static let catalogId = "https://a2ui.org/specification/v0_9/catalogs/basic/catalog.json"

    public var catalogId: String { Self.catalogId }

    public init() {}

    /// Return the catalog schema, **generated from the Swift component types** via
    /// `BasicCatalogSchema` / `SchemaRenderer` — not from a hand-written JSON file.
    ///
    /// The Swift types (component property declarations + `SchemaEnumerable` enums) are the
    /// single source of truth; the LLM-facing schema is derived from them, so the two can never
    /// drift. (A `GeneratedSchemaEquivalence` test pins the output to the official v0.9 catalog.)
    public static func catalogSchemaJSON() -> String {
        BasicCatalogSchema.render()
    }
}

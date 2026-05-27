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

    /// Load the bundled catalog.json and return its contents as a String.
    ///
    /// Returns `"{}"` if the resource cannot be located, which should not
    /// happen in a correctly assembled package.
    public static func catalogSchemaJSON() -> String {
        guard let url = Bundle.module.url(
            forResource: "catalog",
            withExtension: "json",
            subdirectory: "Resources"
        ) else {
            return "{}"
        }
        return (try? String(contentsOf: url, encoding: .utf8)) ?? "{}"
    }
}

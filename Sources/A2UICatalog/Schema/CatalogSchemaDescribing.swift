import A2UICore

/// A component (or function) that describes its own LLM-facing schema in Swift.
///
/// Conforming makes the Swift type the single source of truth for the schema the LLM sees —
/// there is no hand-written `catalog.json`. `SchemaRenderer` collects all conformers' schemas
/// and renders the catalog document.
public protocol CatalogSchemaDescribing {
    /// The type-safe schema for this component.
    static var componentSchema: ComponentSchema { get }
}

/// A `String`-backed enum whose cases populate a schema `enum` list.
/// Conform your component property enums (e.g. `TextVariant`) to expose their cases to the schema.
public protocol SchemaEnumerable: CaseIterable, RawRepresentable where RawValue == String {}

public extension SchemaEnumerable {
    /// All raw case strings, in declaration order — for `PropertyType.enumeration`.
    static var schemaCases: [String] { allCases.map(\.rawValue) }
}

public extension PropertyType {
    /// Build an `.enumeration` from a `SchemaEnumerable` type, avoiding hand-listed case strings.
    static func enumeration<E: SchemaEnumerable>(_ type: E.Type) -> PropertyType {
        .enumeration(E.schemaCases)
    }
}

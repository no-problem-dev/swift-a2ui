import A2UICore

/// A component that carries its own model-facing schema.
///
/// Conforming makes the Swift type the single source of truth for the schema, so no `catalog.json`
/// is written by hand. `BasicCatalogSchema` gathers the schemas of the conforming types and
/// `SchemaRenderer` renders them into the catalog document.
public protocol CatalogSchemaDescribing {
    /// This component's properties, defaults, and prose in the form the renderer emits. Every
    /// `description` inside it reaches the model verbatim.
    static var componentSchema: ComponentSchema { get }
}

/// A `String`-backed enum whose cases become a schema `enum` list.
///
/// Conform a property enum such as `TextVariant` and its cases reach the model straight from
/// Swift, with no enum strings hand-listed in any JSON.
public protocol SchemaEnumerable: CaseIterable, RawRepresentable where RawValue == String {}

public extension SchemaEnumerable {
    /// Raw case strings in declaration order, which is the order they appear in the generated
    /// schema. A call site passes an explicit list instead when the official catalog orders that
    /// property's cases differently.
    static var schemaCases: [String] { allCases.map(\.rawValue) }
}

public extension PropertyType {
    /// Builds an `.enumeration` from a `SchemaEnumerable` type, so the values offered to the model
    /// stay in step with the enum that decodes its reply.
    static func enumeration<E: SchemaEnumerable>(_ type: E.Type) -> PropertyType {
        .enumeration(E.schemaCases)
    }
}

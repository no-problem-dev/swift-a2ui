import A2UICore

/// A type-safe description of one component's contract, used to GENERATE the LLM-facing schema
/// instead of hand-writing `catalog.json`. The Swift types are the single source of truth.
///
/// `SchemaRenderer` turns `[ComponentSchema]` into the official A2UI catalog JSON-Schema document
/// (semantically equivalent to `catalogs/basic/catalog.json`), so the LLM still receives a
/// standards-compliant schema — but nothing is hand-written or duplicated.
public struct ComponentSchema: Sendable, Equatable {
    /// The component name (the `component` discriminator const, e.g. "Text").
    public let name: String
    /// Human description emitted into the schema for the LLM.
    public let description: String?
    /// Declared properties (excluding the implicit `component`/`id`/`weight`, which are shared).
    public let properties: [PropertySchema]
    /// Shared mixins this component participates in (e.g. `Checkable` for inputs / Button).
    public let mixins: [SchemaMixin]

    public init(
        name: String,
        description: String? = nil,
        properties: [PropertySchema],
        mixins: [SchemaMixin] = []
    ) {
        self.name = name
        self.description = description
        self.properties = properties
        self.mixins = mixins
    }

    /// Property names that are required (always includes the implicit `component`).
    public var requiredPropertyNames: [String] {
        ["component"] + properties.filter(\.isRequired).map(\.name)
    }
}

/// Shared schema fragments referenced via `allOf` in the official catalog.
public enum SchemaMixin: String, Sendable, Equatable, CaseIterable {
    /// `common_types.json#/$defs/Checkable` — adds the `checks` array (validation / disable).
    case checkable
}

/// One property in a component schema.
public struct PropertySchema: Sendable, Equatable {
    public let name: String
    public let type: PropertyType
    public let isRequired: Bool
    public let description: String?
    /// Optional default value rendered as the schema `default` (e.g. enum default "body").
    public let defaultValue: AnyCodable?

    public init(
        _ name: String,
        _ type: PropertyType,
        required: Bool = false,
        description: String? = nil,
        default defaultValue: AnyCodable? = nil
    ) {
        self.name = name
        self.type = type
        self.isRequired = required
        self.description = description
        self.defaultValue = defaultValue
    }

    // Ergonomic constructors.
    public static func required(_ name: String, _ type: PropertyType, _ description: String? = nil) -> PropertySchema {
        PropertySchema(name, type, required: true, description: description)
    }

    public static func optional(_ name: String, _ type: PropertyType, _ description: String? = nil, default defaultValue: AnyCodable? = nil) -> PropertySchema {
        PropertySchema(name, type, required: false, description: description, default: defaultValue)
    }
}

/// The type of a component property. Maps to either a common-types `$ref`, an inline scalar,
/// or an enumeration. This is the closed set of property kinds the A2UI basic catalog uses.
public enum PropertyType: Sendable, Equatable {
    // Dynamic (bindable) value types — rendered as common_types.json $refs.
    case dynamicString
    case dynamicNumber
    case dynamicBoolean
    case dynamicStringList
    case dynamicValue
    // Structural references.
    case componentId      // common_types.json#/$defs/ComponentId
    case childList        // common_types.json#/$defs/ChildList
    case action           // common_types.json#/$defs/Action
    // Inline scalars.
    case string
    case number
    case boolean
    /// An inline string enum with its allowed cases.
    case enumeration([String])
    /// An array of a property type (e.g. tabs array of objects).
    indirect case array(PropertyType)
    /// An inline object with named sub-properties (e.g. a tab entry { title, child }).
    case object([PropertySchema])
}

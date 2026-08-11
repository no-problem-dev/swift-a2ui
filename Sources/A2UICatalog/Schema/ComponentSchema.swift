import StructuredDataCore
import A2UICore

/// A type-safe description of one component, from which the model-facing schema is generated
/// instead of being maintained by hand in a `catalog.json`.
///
/// `SchemaRenderer` turns a `[ComponentSchema]` into the A2UI catalog JSON-Schema document,
/// semantically equivalent to `catalogs/basic/catalog.json`.
public struct ComponentSchema: Sendable, Equatable {
    /// Emitted as the `component` discriminator `const` (for example `"Text"`), and required by the
    /// spec to be a valid UAX #31 identifier.
    public let name: String
    /// Display / layout / input grouping, for settings UI, documentation, and catalog browsers.
    /// It never reaches the model: the official `catalog.json` has no category field.
    public let category: ComponentCategory
    /// Prose emitted into the schema — what the model reads to decide when to use the component.
    /// It is written for the model, not for a Swift caller.
    public let description: String?
    /// Properties this component declares on its own. The renderer adds the shared `component`,
    /// `id`, and `weight` fields, so repeating them here would duplicate them.
    public let properties: [PropertySchema]
    /// Shared fragments this component joins through `allOf` — every input component and `Button`
    /// take `.checkable`.
    public let mixins: [SchemaMixin]

    public init(
        name: String,
        category: ComponentCategory,
        description: String? = nil,
        properties: [PropertySchema],
        mixins: [SchemaMixin] = []
    ) {
        self.name = name
        self.category = category
        self.description = description
        self.properties = properties
        self.mixins = mixins
    }

    /// Names for the schema's `required` array. `component` always leads it; the rest follow the
    /// declaration order of `properties`, which the fidelity tests pin to the official catalog.
    public var requiredPropertyNames: [String] {
        ["component"] + properties.filter(\.isRequired).map(\.name)
    }
}

/// Functional grouping of the basic catalog's components, following how the official catalog is
/// organized. The `CaseIterable` declaration order is the canonical order to present them in.
public enum ComponentCategory: String, Sendable, Equatable, CaseIterable {
    case display
    case layout
    case input
}

/// Shared schema fragments the official catalog pulls into a component through `allOf`.
public enum SchemaMixin: String, Sendable, Equatable, CaseIterable {
    /// Adds the `checks` array of `common_types.json#/$defs/Checkable` — the validation rules a
    /// renderer evaluates, each carrying its own failure message.
    case checkable
}

/// One property of a component schema: its name, its type, whether it is required, and the prose
/// the model reads.
public struct PropertySchema: Sendable, Equatable {
    public let name: String
    public let type: PropertyType
    public let isRequired: Bool
    public let description: String?
    /// Emitted as the schema's `default` (for example `"body"` for `Text.variant`), telling the
    /// model what it gets when it leaves the property out.
    public let defaultValue: StructuredValue?

    public init(
        _ name: String,
        _ type: PropertyType,
        required: Bool = false,
        description: String? = nil,
        default defaultValue: StructuredValue? = nil
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

    public static func optional(_ name: String, _ type: PropertyType, _ description: String? = nil, default defaultValue: StructuredValue? = nil) -> PropertySchema {
        PropertySchema(name, type, required: false, description: description, default: defaultValue)
    }
}

/// The closed set of property shapes the A2UI basic catalog uses.
///
/// `$ref`s into common-types, inline scalars, enumerations, and — where the official schema is
/// irregular — a verbatim fragment.
public enum PropertyType: Sendable, Equatable {
    // Bindable dynamic values, rendered as $refs into common_types.json: the model may supply a
    // literal, a data binding, or a function call for any of these.
    case dynamicString
    case dynamicNumber
    case dynamicBoolean
    case dynamicStringList
    case dynamicValue
    // Structural references.
    case componentId      // common_types.json#/$defs/ComponentId
    case child            // common_types.json#/$defs/Child (v1.0: a single child reference)
    case childList        // common_types.json#/$defs/ChildList
    case action           // common_types.json#/$defs/Action
    // Inline scalars.
    case string
    case number
    case integer
    case boolean
    /// Inline string enum; the listed cases are the only values the model may emit here.
    case enumeration([String])
    /// An array of another property type, such as the array of objects behind `Tabs.tabs`.
    indirect case array(PropertyType)
    /// An inline object with named sub-properties, such as a tab entry `{ title, child }`.
    case object([PropertySchema])
    /// A JSON-Schema fragment for properties the cases above cannot express.
    ///
    /// The basic catalog needs it twice: `Icon.name`'s `oneOf`, and `DateTimeInput.min`/`max`'s
    /// `allOf` + `if`/`then`. The fragment is emitted exactly as written, so it must carry its own
    /// `description` — `renderProperty` will not add one, and drops the `PropertySchema`'s.
    case raw(StructuredValue)
}

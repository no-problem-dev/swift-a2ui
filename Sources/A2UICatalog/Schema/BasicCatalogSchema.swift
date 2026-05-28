import A2UICore

/// The Basic Catalog, described entirely in Swift (no hand-written `catalog.json`).
///
/// Aggregates every basic component's `CatalogSchemaDescribing.componentSchema` plus the basic
/// function schemas, and renders the LLM-facing catalog document via `SchemaRenderer`.
public enum BasicCatalogSchema {

    public static let catalogId = BasicComponentCatalog.catalogId

    /// All basic-catalog component schemas (type-derived).
    public static let components: [ComponentSchema] = [
        TextComponent.componentSchema,
        ImageComponent.componentSchema,
        IconComponent.componentSchema,
        VideoComponent.componentSchema,
        AudioPlayerComponent.componentSchema,
        RowComponent.componentSchema,
        ColumnComponent.componentSchema,
        ListComponent.componentSchema,
        CardComponent.componentSchema,
        TabsComponent.componentSchema,
        DividerComponent.componentSchema,
        ModalComponent.componentSchema,
        ButtonComponent.componentSchema,
        TextFieldComponent.componentSchema,
        CheckBoxComponent.componentSchema,
        ChoicePickerComponent.componentSchema,
        SliderComponent.componentSchema,
        DateTimeInputComponent.componentSchema,
    ]

    /// All basic-catalog function schemas (spec §7).
    public static let functions: [FunctionSchema] = [
        FunctionSchema(name: "required", description: "Checks that the value is not null, undefined, or empty.",
                       arguments: [.required("value", .dynamicValue, "The value to check.")], returnType: "boolean"),
        FunctionSchema(name: "regex", description: "Checks that the value matches a regular expression.",
                       arguments: [.required("value", .dynamicString), .required("pattern", .string, "The regex pattern.")], returnType: "boolean"),
        FunctionSchema(name: "length", description: "Checks string length constraints.",
                       arguments: [.required("value", .dynamicString), .optional("min", .number), .optional("max", .number)], returnType: "boolean"),
        FunctionSchema(name: "numeric", description: "Checks numeric range constraints.",
                       arguments: [.required("value", .dynamicValue), .optional("min", .number), .optional("max", .number)], returnType: "boolean"),
        FunctionSchema(name: "email", description: "Checks that the value is a valid email address.",
                       arguments: [.required("value", .dynamicString)], returnType: "boolean"),
        FunctionSchema(name: "formatString", description: "String interpolation of data-model values and functions using ${expression} syntax.",
                       arguments: [.required("value", .string, "The template string with ${...} expressions.")], returnType: "string"),
        FunctionSchema(name: "formatNumber", description: "Formats a number with grouping and precision.",
                       arguments: [.required("value", .dynamicNumber), .optional("decimals", .number), .optional("grouping", .boolean)], returnType: "string"),
        FunctionSchema(name: "formatCurrency", description: "Formats a number as a currency string.",
                       arguments: [.required("value", .dynamicNumber), .required("currency", .string, "ISO 4217 code, e.g. 'USD'.")], returnType: "string"),
        FunctionSchema(name: "formatDate", description: "Formats a timestamp using a Unicode TR35 pattern.",
                       arguments: [.required("value", .dynamicValue), .required("format", .dynamicString)], returnType: "string"),
        FunctionSchema(name: "pluralize", description: "Selects a localized string based on a numeric count (CLDR categories).",
                       arguments: [.required("value", .dynamicNumber), .required("other", .dynamicString, "Required fallback category.")], returnType: "string"),
        FunctionSchema(name: "openUrl", description: "Opens a URL (side effect).",
                       arguments: [.required("url", .dynamicString)], returnType: "void"),
        FunctionSchema(name: "and", description: "Logical AND over a list of booleans.",
                       arguments: [.required("values", .array(.dynamicBoolean))], returnType: "boolean"),
        FunctionSchema(name: "or", description: "Logical OR over a list of booleans.",
                       arguments: [.required("values", .array(.dynamicBoolean))], returnType: "boolean"),
        FunctionSchema(name: "not", description: "Logical NOT of a boolean.",
                       arguments: [.required("value", .dynamicBoolean)], returnType: "boolean"),
    ]

    /// Render the basic catalog document as a minified JSON string for the LLM prompt.
    public static func render() -> String {
        SchemaRenderer.renderCatalog(
            catalogId: catalogId,
            title: "A2UI Basic Catalog",
            description: "Unified catalog of basic A2UI components and functions.",
            components: components,
            functions: functions
        )
    }
}

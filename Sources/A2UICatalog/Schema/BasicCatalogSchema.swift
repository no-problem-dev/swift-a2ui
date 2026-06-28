import A2UICore

// MARK: - Function-arg helpers (verbatim official catalog.json fragments)

private func fnURL(_ name: String) -> StructuredValue {
    .string("https://a2ui.org/specification/v0_10/common_types.json#/$defs/\(name)")
}
private func fnRef(_ name: String) -> StructuredValue { .object(["$ref": fnURL(name)]) }
private func fnRefD(_ name: String, _ description: String) -> StructuredValue {
    .object(["$ref": fnURL(name), "description": .string(description)])
}

/// Build a function `args` object: properties + required (+ optional `anyOf` of single-required) +
/// `unevaluatedProperties:false` (the shape used by all `$ref`-typed function args).
private func argsObj(props: OrderedObject, required: [String], anyOfRequired: [String]? = nil) -> StructuredValue {
    var obj: OrderedObject = [
        "type": .string("object"),
        "properties": .object(props),
        "required": .array(required.map { .string($0) }),
        "unevaluatedProperties": .bool(false),
    ]
    if let anyOfRequired {
        obj["anyOf"] = .array(anyOfRequired.map { .object(["required": .array([.string($0)])]) })
    }
    return .object(obj)
}

private let decimalsDesc = "Optional. The number of decimal places to show. Defaults to 0 or 2 depending on locale."
private let groupingDesc = "Optional. If true, uses locale-specific grouping separators (e.g. '1,000'). If false, returns raw digits (e.g. '1000'). Defaults to true."
private let boolListArg: StructuredValue = .object([
    "type": .string("array"),
    "description": .string("The list of boolean values to evaluate."),
    "items": fnRef("DynamicBoolean"),
    "minItems": .int(2),
])
private let tr35Desc = """
A Unicode TR35 date pattern string.

Token Reference:
- Year: 'yy' (26), 'yyyy' (2026)
- Month: 'M' (1), 'MM' (01), 'MMM' (Jan), 'MMMM' (January)
- Day: 'd' (1), 'dd' (01), 'E' (Tue), 'EEEE' (Tuesday)
- Hour (12h): 'h' (1-12), 'hh' (01-12) - requires 'a' for AM/PM
- Hour (24h): 'H' (0-23), 'HH' (00-23) - Military Time
- Minute: 'mm' (00-59)
- Second: 'ss' (00-59)
- Period: 'a' (AM/PM)

Examples:
- 'MMM dd, yyyy' -> 'Jan 16, 2026'
- 'HH:mm' -> '14:30' (Military)
- 'h:mm a' -> '2:30 PM'
- 'EEEE, d MMMM' -> 'Friday, 16 January'
"""

/// Basic カタログを Swift で完全に記述したもの（手書き `catalog.json` は不要）。
///
/// 各 basic コンポーネントの `CatalogSchemaDescribing.componentSchema` と基本関数スキーマを集約し、
/// `SchemaRenderer` で LLM 向けカタログドキュメントをレンダリングする。
public enum BasicCatalogSchema {

    public static let catalogId = BasicComponentCatalog.catalogId

    /// すべての basic カタログコンポーネントスキーマ（型から導出）。
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
        ModalComponent.componentSchema,
        DividerComponent.componentSchema,
        ButtonComponent.componentSchema,
        TextFieldComponent.componentSchema,
        CheckBoxComponent.componentSchema,
        ChoicePickerComponent.componentSchema,
        SliderComponent.componentSchema,
        DateTimeInputComponent.componentSchema,
    ]

    /// すべての basic カタログ関数スキーマ（仕様 §7）。各 `description` と引数形状は
    /// 公式 `catalog.json` からそのまま転記（`GeneratedCatalogFidelityTests` で固定）。
    public static let functions: [FunctionSchema] = [
        FunctionSchema(name: "required", description: "Checks that the value is not null, undefined, or empty.",
            argsObject: .object([
                "type": .string("object"),
                "properties": .object(["value": .object(["description": .string("The value to check.")])]),
                "required": .array([.string("value")]),
                "additionalProperties": .bool(false),
            ]), returnType: "boolean"),
        FunctionSchema(name: "regex", description: "Checks that the value matches a regular expression string.",
            argsObject: argsObj(
                props: ["value": fnRef("DynamicString"),
                        "pattern": .object(["type": .string("string"), "description": .string("The regex pattern to match against.")])],
                required: ["value", "pattern"]), returnType: "boolean"),
        FunctionSchema(name: "length", description: "Checks string length constraints.",
            argsObject: argsObj(
                props: ["value": fnRef("DynamicString"),
                        "min": .object(["type": .string("integer"), "minimum": .int(0), "description": .string("The minimum allowed length.")]),
                        "max": .object(["type": .string("integer"), "minimum": .int(0), "description": .string("The maximum allowed length.")])],
                required: ["value"], anyOfRequired: ["min", "max"]), returnType: "boolean"),
        FunctionSchema(name: "numeric", description: "Checks numeric range constraints.",
            argsObject: argsObj(
                props: ["value": fnRef("DynamicNumber"),
                        "min": .object(["type": .string("number"), "description": .string("The minimum allowed value.")]),
                        "max": .object(["type": .string("number"), "description": .string("The maximum allowed value.")])],
                required: ["value"], anyOfRequired: ["min", "max"]), returnType: "boolean"),
        FunctionSchema(name: "email", description: "Checks that the value is a valid email address.",
            argsObject: argsObj(props: ["value": fnRef("DynamicString")], required: ["value"]), returnType: "boolean"),
        FunctionSchema(name: "formatString", description: "Performs string interpolation of data model values and other functions in the catalog functions list and returns the resulting string. The value string can contain interpolated expressions in the `${expression}` format. Supported expression types include: JSON Pointer paths to the data model (e.g., `${/absolute/path}` or `${relative/path}`), and client-side function calls (e.g., `${now()}`). Function arguments must be named (e.g., `${formatDate(value:${/currentDate}, format:'MM-dd')}`). To include a literal `${` sequence, escape it as `\\${`.",
            argsObject: argsObj(props: ["value": fnRef("DynamicString")], required: ["value"]), returnType: "string"),
        FunctionSchema(name: "formatNumber", description: "Formats a number with the specified grouping and decimal precision.",
            argsObject: argsObj(
                props: ["value": fnRefD("DynamicNumber", "The number to format."),
                        "decimals": fnRefD("DynamicNumber", decimalsDesc),
                        "grouping": fnRefD("DynamicBoolean", groupingDesc)],
                required: ["value"]), returnType: "string"),
        FunctionSchema(name: "formatCurrency", description: "Formats a number as a currency string.",
            argsObject: argsObj(
                props: ["value": fnRefD("DynamicNumber", "The monetary amount."),
                        "currency": fnRefD("DynamicString", "The ISO 4217 currency code (e.g., 'USD', 'EUR')."),
                        "decimals": fnRefD("DynamicNumber", decimalsDesc),
                        "grouping": fnRefD("DynamicBoolean", groupingDesc)],
                required: ["currency", "value"]), returnType: "string"),
        FunctionSchema(name: "formatDate", description: "Formats a timestamp into a string using a pattern.",
            argsObject: argsObj(
                props: ["value": fnRefD("DynamicValue", "The date to format."),
                        "format": fnRefD("DynamicString", tr35Desc)],
                required: ["format", "value"]), returnType: "string"),
        FunctionSchema(name: "pluralize", description: "Returns a localized string based on the Common Locale Data Repository (CLDR) plural category of the count (zero, one, two, few, many, other). Requires an 'other' fallback. For English, just use 'one' and 'other'.",
            argsObject: argsObj(
                props: ["value": fnRefD("DynamicNumber", "The numeric value used to determine the plural category."),
                        "zero": fnRefD("DynamicString", "String for the 'zero' category (e.g., 0 items)."),
                        "one": fnRefD("DynamicString", "String for the 'one' category (e.g., 1 item)."),
                        "two": fnRefD("DynamicString", "String for the 'two' category (used in Arabic, Welsh, etc.)."),
                        "few": fnRefD("DynamicString", "String for the 'few' category (e.g., small groups in Slavic languages)."),
                        "many": fnRefD("DynamicString", "String for the 'many' category (e.g., large groups in various languages)."),
                        "other": fnRefD("DynamicString", "The default/fallback string (used for general plural cases).")],
                required: ["value", "other"]), returnType: "string"),
        FunctionSchema(name: "openUrl", description: "Opens the specified URL in a browser or handler. This function has no return value.",
            argsObject: .object([
                "type": .string("object"),
                "properties": .object(["url": .object(["type": .string("string"), "format": .string("uri"), "description": .string("The URL to open.")])]),
                "required": .array([.string("url")]),
                "additionalProperties": .bool(false),
            ]), returnType: "void"),
        FunctionSchema(name: "and", description: "Performs a logical AND operation on a list of boolean values.",
            argsObject: argsObj(props: ["values": boolListArg], required: ["values"]), returnType: "boolean"),
        FunctionSchema(name: "or", description: "Performs a logical OR operation on a list of boolean values.",
            argsObject: argsObj(props: ["values": boolListArg], required: ["values"]), returnType: "boolean"),
        FunctionSchema(name: "not", description: "Performs a logical NOT operation on a boolean value.",
            argsObject: argsObj(props: ["value": fnRefD("DynamicBoolean", "The boolean value to negate.")], required: ["value"]), returnType: "boolean"),
    ]

    /// LLM プロンプト用の最小化 JSON 文字列として basic カタログドキュメントをレンダリングする。
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

import A2UICore
import Foundation

/// タイプセーフな `ComponentSchema` を公式 A2UI カタログ JSON-Schema ドキュメントに変換するレンダラー。
///
/// 出力は `catalogs/basic/catalog.json` と意味的に等価。`allOf` + common-types `$ref` 形式、
/// `component` const ディスクリミネータ、`required` リストはすべて公式仕様に準拠する。
/// ただし生成元は Swift 型であり、手書きのカタログ JSON は存在しない。
public enum SchemaRenderer {

    private static let commonTypesBase = "https://a2ui.org/specification/v1_0/common_types.json#/$defs/"

    /// `catalog_definition.json` の `protocolVersion`。v1.0 以降を狙うカタログは必須で、
    /// 省略すると後方互換のため `"0.9"` とみなされる。
    public static let protocolVersion = "1.0"

    /// 全コンポーネント共通の `weight`（v1.0 で各コンポーネントに直接載るようになった）。
    private static let weightProperty: StructuredValue = .object([
        "type": .string("number"),
        "description": .string("The relative weight of this component within a Row or Column. This is similar to the CSS 'flex-grow' property. Note: this may ONLY be set when the component is a direct descendant of a Row or Column."),
    ])

    /// 指定したカタログ id・コンポーネントスキーマ・関数スキーマからカタログドキュメントをレンダリングする。
    /// LLM システムプロンプトへの埋め込みに適した最小化 JSON 文字列を返す。
    public static func renderCatalog(
        catalogId: String,
        title: String,
        description: String,
        instructions: String? = nil,
        components: [ComponentSchema],
        functions: [FunctionSchema]
    ) -> String {
        var componentDefs: OrderedObject = [:]
        for component in components {
            componentDefs[component.name] = renderComponent(component)
        }

        var functionDefs: OrderedObject = [:]
        for fn in functions {
            functionDefs[fn.name] = renderFunction(fn)
        }

        var doc: OrderedObject = [
            "$schema": .string("https://json-schema.org/draft/2020-12/schema"),
            "$id": .string(catalogId),
            // v1.0: catalogs targeting 1.0 and beyond MUST declare this. Omitting it means "0.9".
            "protocolVersion": .string(Self.protocolVersion),
            "title": .string(title),
            "description": .string(description),
            "catalogId": .string(catalogId),
        ]
        // v1.0: design guidelines embedded in the catalog, replacing the external rules.txt.
        if let instructions {
            doc["instructions"] = .string(instructions)
        }
        doc["components"] = .object(componentDefs)
        doc["functions"] = .object(functionDefs)
        doc["$defs"] = renderDefs(
            componentNames: components.map(\.name),
            functionNames: functions.map(\.name)
        )

        return minify(.object(doc))
    }

    // MARK: - Catalog `$defs` (shared fragments referenced by components / s2c / common_types)

    /// The catalog's `$defs` block, reproduced verbatim from the official `catalog.json`:
    /// the `anyComponent` / `anyFunction` discriminated unions (order follows the catalog's
    /// component / function order).
    ///
    /// v1.0 removed `theme` (layout is separated from branding) and folded the shared `weight`
    /// property into each component's own schema, so `CatalogComponentCommon` is gone too.
    static func renderDefs(componentNames: [String], functionNames: [String]) -> StructuredValue {
        .object([
            "anyComponent": .object([
                "oneOf": .array(componentNames.map { .object(["$ref": .string("#/components/\($0)")]) }),
                "discriminator": .object(["propertyName": .string("component")]),
            ]),
            "anyFunction": .object([
                "oneOf": .array(functionNames.map { .object(["$ref": .string("#/functions/\($0)")]) }),
            ]),
        ])
    }

    /// `components` マップ(コンポーネント名 → JSON Schema)単体をレンダリングする。
    ///
    /// クライアントがカタログ対応を宣言する(A2UIAGUI の schema context の
    /// `{catalogId, components}`)ときの `components` に使う。カタログドキュメント
    /// 全体ではなく、`renderCatalog` の `components` ブロックと同じ形。
    public static func renderComponents(_ components: [ComponentSchema]) -> StructuredValue {
        var componentDefs: OrderedObject = [:]
        for component in components {
            componentDefs[component.name] = renderComponent(component)
        }
        return .object(componentDefs)
    }

    // MARK: - Component rendering

    static func renderComponent(_ component: ComponentSchema) -> StructuredValue {
        // v1.0: only ComponentCommon is shared by $ref; `weight` is declared inline per component.
        var allOf: [StructuredValue] = [ref("ComponentCommon")]
        for mixin in component.mixins {
            switch mixin {
            case .checkable:
                allOf.append(ref("Checkable"))
            }
        }

        var properties: OrderedObject = [
            "component": .object(["const": .string(component.name)]),
        ]
        for prop in component.properties {
            properties[prop.name] = renderProperty(prop)
        }
        // v1.0 folded the former CatalogComponentCommon `$ref` into each component; the shape is
        // identical for all 18, so it is appended here rather than repeated in every type.
        properties["weight"] = Self.weightProperty

        var inner: OrderedObject = [
            "type": .string("object"),
            "properties": .object(properties),
            "required": .array(component.requiredPropertyNames.map(StructuredValue.string)),
        ]
        if let description = component.description {
            inner["description"] = .string(description)
        }
        allOf.append(.object(inner))

        return .object([
            "type": .string("object"),
            "allOf": .array(allOf),
            "unevaluatedProperties": .bool(false),
        ])
    }

    static func renderProperty(_ prop: PropertySchema) -> StructuredValue {
        // `.raw` fragments are emitted verbatim (they already carry their own description).
        if case .raw(let value) = prop.type { return value }
        var node = renderType(prop.type)
        if case .object(var dict) = node {
            if let description = prop.description { dict["description"] = .string(description) }
            if let def = prop.defaultValue { dict["default"] = def }
            node = .object(dict)
        }
        return node
    }

    static func renderType(_ type: PropertyType) -> StructuredValue {
        switch type {
        case .dynamicString: return ref("DynamicString")
        case .dynamicNumber: return ref("DynamicNumber")
        case .dynamicBoolean: return ref("DynamicBoolean")
        case .dynamicStringList: return ref("DynamicStringList")
        case .dynamicValue: return ref("DynamicValue")
        case .componentId: return ref("ComponentId")
        case .child: return ref("Child")
        case .childList: return ref("ChildList")
        case .action: return ref("Action")
        case .string: return .object(["type": .string("string")])
        case .number: return .object(["type": .string("number")])
        case .integer: return .object(["type": .string("integer")])
        case .boolean: return .object(["type": .string("boolean")])
        case .enumeration(let cases):
            return .object([
                "type": .string("string"),
                "enum": .array(cases.map(StructuredValue.string)),
            ])
        case .array(let element):
            return .object(["type": .string("array"), "items": renderType(element)])
        case .object(let props):
            var properties: OrderedObject = [:]
            var required: [StructuredValue] = []
            for p in props {
                properties[p.name] = renderProperty(p)
                if p.isRequired { required.append(.string(p.name)) }
            }
            var obj: OrderedObject = ["type": .string("object"), "properties": .object(properties)]
            if !required.isEmpty { obj["required"] = .array(required) }
            return .object(obj)
        case .raw(let value):
            return value
        }
    }

    // MARK: - Function rendering

    static func renderFunction(_ fn: FunctionSchema) -> StructuredValue {
        let argsValue: StructuredValue
        if let override = fn.argsObject {
            // Verbatim official `args` object (the irregular shapes).
            argsValue = override
        } else {
            var argProps: OrderedObject = [:]
            var argRequired: [StructuredValue] = []
            for arg in fn.arguments {
                argProps[arg.name] = renderProperty(arg)
                if arg.isRequired { argRequired.append(.string(arg.name)) }
            }
            var argsObj: OrderedObject = [
                "type": .string("object"),
                "properties": .object(argProps),
            ]
            if !argRequired.isEmpty { argsObj["required"] = .array(argRequired) }
            argsObj["unevaluatedProperties"] = .bool(false)
            argsValue = .object(argsObj)
        }

        // v1.0: functions are `allOf: [FunctionCommon, {call/args}]` with `returnType` hoisted to
        // the function level as static catalog metadata (it left the wire payload entirely).
        let inner: OrderedObject = [
            "type": .string("object"),
            "properties": .object([
                "call": .object(["const": .string(fn.name)]),
                "args": argsValue,
            ]),
            "required": .array([.string("call"), .string("args")]),
        ]

        var node: OrderedObject = ["type": .string("object")]
        if let description = fn.description { node["description"] = .string(description) }
        node["returnType"] = .string(fn.returnType)
        if let callableFrom = fn.callableFrom {
            node["callableFrom"] = .string(callableFrom)
        }
        node["allOf"] = .array([ref("FunctionCommon"), .object(inner)])
        node["unevaluatedProperties"] = .bool(false)
        return .object(node)
    }

    // MARK: - Helpers

    private static func ref(_ name: String) -> StructuredValue {
        .object(["$ref": .string(commonTypesRef(name))])
    }

    /// `common_types.json#/$defs/<name>` の絶対 URI。`.raw` フラグメントを手書きするスキーマから使う。
    public static func commonTypesRef(_ name: String) -> String {
        commonTypesBase + name
    }

    // MARK: - Identifier validation (v1.0 §Catalog entity naming)

    /// カタログの識別子が UAX #31 に適合しているかを検査し、違反を返す（適合していれば空）。
    ///
    /// 対象はコンポーネント名・関数名・引数/プロパティ名。仕様がこれを **MUST** としているのは
    /// SDK・パーサー・コードジェネレータをまたいだ互換性のため。
    public static func identifierViolations(
        components: [ComponentSchema],
        functions: [FunctionSchema]
    ) -> [String] {
        var violations: [String] = []
        for component in components {
            if !CatalogIdentifier.isValid(component.name) {
                violations.append("component name '\(component.name)'")
            }
            for property in component.properties where !CatalogIdentifier.isValid(property.name) {
                violations.append("\(component.name).\(property.name)")
            }
        }
        for function in functions {
            if !CatalogIdentifier.isValid(function.name) {
                violations.append("function name '\(function.name)'")
            }
            for argument in function.arguments where !CatalogIdentifier.isValid(argument.name) {
                violations.append("\(function.name)(\(argument.name))")
            }
        }
        return violations
    }

    static func minify(_ value: StructuredValue) -> String {
        return JSONSerializer(options: .init(sortKeys: true)).string(from: value)
    }
}

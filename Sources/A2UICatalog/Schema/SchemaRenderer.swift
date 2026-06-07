import A2UICore
import Foundation

/// Renders type-safe `ComponentSchema`s into the official A2UI catalog JSON-Schema document.
///
/// The output is semantically equivalent to `catalogs/basic/catalog.json` — components use the
/// same `allOf` + common-types `$ref` shape, `component` const discriminator, and `required` list —
/// but it is GENERATED from Swift types, so there is no hand-written catalog JSON to drift.
public enum SchemaRenderer {

    private static let commonTypesBase = "https://a2ui.org/specification/v0_10/common_types.json#/$defs/"

    /// Render the full catalog document for the given catalog id + component schemas + functions.
    /// Returns a minified JSON string suitable for embedding in the LLM system prompt.
    public static func renderCatalog(
        catalogId: String,
        title: String,
        description: String,
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

        let doc: StructuredValue = .object([
            "$schema": .string("https://json-schema.org/draft/2020-12/schema"),
            "$id": .string(catalogId),
            "title": .string(title),
            "description": .string(description),
            "catalogId": .string(catalogId),
            "components": .object(componentDefs),
            "functions": .object(functionDefs),
            "$defs": renderDefs(componentNames: components.map(\.name), functionNames: functions.map(\.name)),
        ])

        return minify(doc)
    }

    // MARK: - Catalog `$defs` (shared fragments referenced by components / s2c / common_types)

    /// The catalog's `$defs` block, reproduced verbatim from the official `catalog.json`:
    /// `CatalogComponentCommon` (the shared `weight` prop), `theme`, and the `anyComponent` /
    /// `anyFunction` discriminated unions (order follows the catalog's component / function order).
    static func renderDefs(componentNames: [String], functionNames: [String]) -> StructuredValue {
        .object([
            "CatalogComponentCommon": .object([
                "type": .string("object"),
                "properties": .object([
                    "weight": .object([
                        "type": .string("number"),
                        "description": .string("The relative weight of this component within a Row or Column. This is similar to the CSS 'flex-grow' property. Note: this may ONLY be set when the component is a direct descendant of a Row or Column."),
                    ]),
                ]),
            ]),
            "theme": .object([
                "type": .string("object"),
                "properties": .object([
                    "primaryColor": .object([
                        "type": .string("string"),
                        "description": .string("The primary brand color used for highlights (e.g., primary buttons, active borders). Renderers may generate variants of this color for different contexts. Format: Hexadecimal code (e.g., '#00BFFF')."),
                        "pattern": .string("^#[0-9a-fA-F]{6}$"),
                    ]),
                    "iconUrl": .object([
                        "type": .string("string"),
                        "format": .string("uri"),
                        "description": .string("A URL for an image that identifies the agent or tool associated with the surface."),
                    ]),
                    "agentDisplayName": .object([
                        "type": .string("string"),
                        "description": .string("Text to be displayed next to the surface to identify the agent or tool that created it."),
                    ]),
                ]),
                "additionalProperties": .bool(true),
            ]),
            "anyComponent": .object([
                "oneOf": .array(componentNames.map { .object(["$ref": .string("#/components/\($0)")]) }),
                "discriminator": .object(["propertyName": .string("component")]),
            ]),
            "anyFunction": .object([
                "oneOf": .array(functionNames.map { .object(["$ref": .string("#/functions/\($0)")]) }),
            ]),
        ])
    }

    // MARK: - Component rendering

    static func renderComponent(_ component: ComponentSchema) -> StructuredValue {
        var allOf: [StructuredValue] = [
            ref("ComponentCommon"),
            .object(["$ref": .string("#/$defs/CatalogComponentCommon")]),
        ]
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

        let properties: OrderedObject = [
            "call": .object(["const": .string(fn.name)]),
            "args": argsValue,
            "returnType": .object(["const": .string(fn.returnType)]),
        ]
        _ = properties  // keep order deterministic via sortedKeys minify

        var node: OrderedObject = [
            "type": .string("object"),
            "properties": .object(properties),
            "required": .array([.string("call"), .string("args")]),
            "unevaluatedProperties": .bool(false),
        ]
        if let description = fn.description { node["description"] = .string(description) }
        return .object(node)
    }

    // MARK: - Helpers

    private static func ref(_ name: String) -> StructuredValue {
        .object(["$ref": .string(commonTypesBase + name)])
    }

    static func minify(_ value: StructuredValue) -> String {
        return JSONSerializer(options: .init(sortKeys: true)).string(from: value)
    }
}

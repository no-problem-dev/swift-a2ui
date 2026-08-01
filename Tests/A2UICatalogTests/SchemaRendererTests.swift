import Testing
@testable import A2UICatalog
import A2UICore
import Foundation

@Suite("SchemaRenderer: component rendering")
struct SchemaRendererComponentTests {

    /// Decode a rendered component back to JSON for structural assertions.
    private func render(_ schema: ComponentSchema) -> [String: Any] {
        let node = SchemaRenderer.renderComponent(schema)
        let data = SchemaRenderer.minify(node).data(using: .utf8)!
        return (try! JSONSerialization.jsonObject(with: data)) as! [String: Any]
    }

    @Test("Text schema matches official shape: component const, text $ref, variant enum, required")
    func textSchema() {
        let schema = ComponentSchema(
            name: "Text",
            category: .display,
            properties: [
                .required("text", .dynamicString, "The text content to display."),
                .optional("variant", .enumeration(["caption", "body"]), default: .string("body")),
            ]
        )
        let json = render(schema)
        let allOf = json["allOf"] as! [[String: Any]]
        // The last allOf entry is the component-specific object.
        let inner = allOf.last!
        let props = inner["properties"] as! [String: Any]

        // component const
        #expect((props["component"] as! [String: Any])["const"] as? String == "Text")
        // text → DynamicString $ref
        let text = props["text"] as! [String: Any]
        #expect(text["$ref"] as? String == "https://a2ui.org/specification/v1_0/common_types.json#/$defs/DynamicString")
        #expect(text["description"] as? String == "The text content to display.")
        // variant → string enum + default
        let variant = props["variant"] as! [String: Any]
        #expect(variant["type"] as? String == "string")
        #expect(variant["enum"] as! [String] == ["caption", "body"])
        #expect(variant["default"] as? String == "body")
        // v1.0 folded the shared `weight` into every component's own schema.
        #expect((props["weight"] as! [String: Any])["type"] as? String == "number")
        // required includes component + text, not variant
        let required = inner["required"] as! [String]
        #expect(Set(required) == ["component", "text"])

        // v1.0 dropped CatalogComponentCommon: only ComponentCommon + the inner object remain.
        #expect(allOf.count == 2)
        #expect((allOf[0]["$ref"] as? String)?.hasSuffix("ComponentCommon") == true)
        // Official catalog marks every component object `unevaluatedProperties: false`.
        #expect(json["unevaluatedProperties"] as? Bool == false)
    }

    @Test("Button schema includes Checkable mixin + child(Child) + action(Action)")
    func buttonSchema() {
        let schema = ComponentSchema(
            name: "Button",
            category: .input,
            properties: [
                .required("child", .child),
                .optional("variant", .enumeration(["default", "primary", "borderless"]), default: .string("default")),
                .required("action", .action),
            ],
            mixins: [.checkable]
        )
        let json = render(schema)
        let allOf = json["allOf"] as! [[String: Any]]
        // v1.0: ComponentCommon, Checkable, then the inner object = 3 entries.
        #expect(allOf.count == 3)
        #expect((allOf[1]["$ref"] as? String)?.hasSuffix("Checkable") == true)

        let inner = allOf.last!
        let props = inner["properties"] as! [String: Any]
        #expect((props["child"] as! [String: Any])["$ref"] as? String == "https://a2ui.org/specification/v1_0/common_types.json#/$defs/Child")
        #expect((props["action"] as! [String: Any])["$ref"] as? String == "https://a2ui.org/specification/v1_0/common_types.json#/$defs/Action")
        #expect(Set(inner["required"] as! [String]) == ["component", "child", "action"])
    }

    @Test("childList property renders as ChildList $ref")
    func childListProperty() {
        let schema = ComponentSchema(name: "Column", category: .layout, properties: [.required("children", .childList)])
        let json = render(schema)
        let inner = (json["allOf"] as! [[String: Any]]).last!
        let props = inner["properties"] as! [String: Any]
        #expect((props["children"] as! [String: Any])["$ref"] as? String == "https://a2ui.org/specification/v1_0/common_types.json#/$defs/ChildList")
    }
}

@Suite("SchemaRenderer: SchemaEnumerable")
struct SchemaEnumerableTests {

    @Test("enumeration(_:) derives cases from a SchemaEnumerable enum")
    func enumerationFromType() {
        if case .enumeration(let cases) = PropertyType.enumeration(TextVariant.self) {
            #expect(cases == ["caption", "body"])
        } else {
            Issue.record("expected .enumeration")
        }
    }
}

@Suite("SchemaRenderer: full catalog document")
struct SchemaRendererCatalogTests {

    @Test("renders a catalog with components + functions + ids")
    func fullCatalog() {
        let doc = SchemaRenderer.renderCatalog(
            catalogId: "https://example.com/cat.json",
            title: "Test",
            description: "desc",
            components: [ComponentSchema(name: "Text", category: .display, properties: [.required("text", .dynamicString)])],
            functions: [FunctionSchema(name: "required", description: "Checks presence.", arguments: [.required("value", .dynamicValue, "The value to check.")], returnType: "boolean")]
        )
        let json = (try! JSONSerialization.jsonObject(with: doc.data(using: .utf8)!)) as! [String: Any]
        #expect(json["catalogId"] as? String == "https://example.com/cat.json")
        // v1.0: catalogs targeting 1.0+ MUST declare protocolVersion (omitting it means "0.9").
        #expect(json["protocolVersion"] as? String == "1.0")
        #expect((json["components"] as! [String: Any])["Text"] != nil)
        let fn = (json["functions"] as! [String: Any])["required"] as! [String: Any]
        // v1.0: functions are allOf: [FunctionCommon, {call, args}] with returnType hoisted.
        let fnInner = (fn["allOf"] as! [[String: Any]]).last!
        #expect(((fnInner["properties"] as! [String: Any])["call"] as! [String: Any])["const"] as? String == "required")
        #expect(fn["returnType"] as? String == "boolean")
    }

    @Test("instructions is emitted only when provided")
    func instructionsOptional() {
        func doc(instructions: String?) -> [String: Any] {
            let rendered = SchemaRenderer.renderCatalog(
                catalogId: "https://example.com/cat.json",
                title: "Test",
                description: "desc",
                instructions: instructions,
                components: [ComponentSchema(name: "Text", category: .display, properties: [.required("text", .dynamicString)])],
                functions: []
            )
            return (try! JSONSerialization.jsonObject(with: rendered.data(using: .utf8)!)) as! [String: Any]
        }
        #expect(doc(instructions: nil)["instructions"] == nil)
        #expect(doc(instructions: "Use Row and Column.")["instructions"] as? String == "Use Row and Column.")
    }
}

@Suite("SchemaRenderer: renderComponents(宣言用 components マップ)")
struct SchemaRendererComponentsMapTests {

    @Test("コンポーネント名をキーに renderComponent と同じ定義を並べる")
    func componentsMapMatchesIndividualRendering() {
        let text = ComponentSchema(
            name: "Text",
            category: .display,
            properties: [.required("text", .dynamicString, "The text content.")]
        )
        let card = ComponentSchema(
            name: "Card",
            category: .layout,
            properties: [.optional("child", .componentId, "Child component id.")]
        )
        let map = SchemaRenderer.renderComponents([text, card])
        let object = map.objectValue
        #expect(object?.keys == ["Text", "Card"])
        #expect(object?["Text"] == SchemaRenderer.renderComponent(text))
        #expect(object?["Card"] == SchemaRenderer.renderComponent(card))
    }
}

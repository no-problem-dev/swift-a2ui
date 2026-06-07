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
                .optional("variant", .enumeration(["h1", "h2", "h3", "h4", "h5", "caption", "body"]), default: .string("body")),
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
        #expect(text["$ref"] as? String == "https://a2ui.org/specification/v0_10/common_types.json#/$defs/DynamicString")
        #expect(text["description"] as? String == "The text content to display.")
        // variant → string enum + default
        let variant = props["variant"] as! [String: Any]
        #expect(variant["type"] as? String == "string")
        #expect(variant["enum"] as! [String] == ["h1", "h2", "h3", "h4", "h5", "caption", "body"])
        #expect(variant["default"] as? String == "body")
        // required includes component + text, not variant
        let required = inner["required"] as! [String]
        #expect(Set(required) == ["component", "text"])

        // mixins: ComponentCommon + CatalogComponentCommon
        #expect(allOf.count == 3)
        #expect((allOf[0]["$ref"] as? String)?.hasSuffix("ComponentCommon") == true)
        // Official catalog marks every component object `unevaluatedProperties: false`.
        #expect(json["unevaluatedProperties"] as? Bool == false)
    }

    @Test("Button schema includes Checkable mixin + child(ComponentId) + action(Action)")
    func buttonSchema() {
        let schema = ComponentSchema(
            name: "Button",
            category: .input,
            properties: [
                .required("child", .componentId),
                .optional("variant", .enumeration(["default", "primary", "borderless"]), default: .string("default")),
                .required("action", .action),
            ],
            mixins: [.checkable]
        )
        let json = render(schema)
        let allOf = json["allOf"] as! [[String: Any]]
        // ComponentCommon, CatalogComponentCommon, Checkable, then inner = 4 entries
        #expect(allOf.count == 4)
        #expect((allOf[2]["$ref"] as? String)?.hasSuffix("Checkable") == true)

        let inner = allOf.last!
        let props = inner["properties"] as! [String: Any]
        #expect((props["child"] as! [String: Any])["$ref"] as? String == "https://a2ui.org/specification/v0_10/common_types.json#/$defs/ComponentId")
        #expect((props["action"] as! [String: Any])["$ref"] as? String == "https://a2ui.org/specification/v0_10/common_types.json#/$defs/Action")
        #expect(Set(inner["required"] as! [String]) == ["component", "child", "action"])
    }

    @Test("childList property renders as ChildList $ref")
    func childListProperty() {
        let schema = ComponentSchema(name: "Column", category: .layout, properties: [.required("children", .childList)])
        let json = render(schema)
        let inner = (json["allOf"] as! [[String: Any]]).last!
        let props = inner["properties"] as! [String: Any]
        #expect((props["children"] as! [String: Any])["$ref"] as? String == "https://a2ui.org/specification/v0_10/common_types.json#/$defs/ChildList")
    }
}

@Suite("SchemaRenderer: SchemaEnumerable")
struct SchemaEnumerableTests {

    @Test("enumeration(_:) derives cases from a SchemaEnumerable enum")
    func enumerationFromType() {
        if case .enumeration(let cases) = PropertyType.enumeration(TextVariant.self) {
            #expect(cases == ["h1", "h2", "h3", "h4", "h5", "caption", "body"])
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
        #expect((json["components"] as! [String: Any])["Text"] != nil)
        let fn = (json["functions"] as! [String: Any])["required"] as! [String: Any]
        #expect(((fn["properties"] as! [String: Any])["call"] as! [String: Any])["const"] as? String == "required")
        #expect((fn["returnType"]) == nil)  // returnType is under properties, not top-level
    }
}

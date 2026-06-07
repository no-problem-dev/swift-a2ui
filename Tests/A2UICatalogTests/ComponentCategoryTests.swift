import Testing

@testable import A2UICatalog

// Pins the consumer-facing category metadata on `BasicCatalogSchema.components`. Settings UIs and
// catalog browsers derive their grouping from this — a new component MUST declare its category,
// and this test fails loudly if the palette or the grouping drifts.
@Suite("ComponentSchema category metadata")
struct ComponentCategoryTests {

    @Test("canonical category order is display, layout, input")
    func categoryOrder() {
        #expect(ComponentCategory.allCases == [.display, .layout, .input])
    }

    @Test("all 18 basic components carry the official category grouping")
    func basicCatalogCategories() {
        let byCategory = Dictionary(grouping: BasicCatalogSchema.components, by: \.category)
            .mapValues { $0.map(\.name) }

        #expect(BasicCatalogSchema.components.count == 18)
        #expect(byCategory[.display] == ["Text", "Image", "Icon", "Video", "AudioPlayer"])
        #expect(byCategory[.layout] == ["Row", "Column", "List", "Card", "Tabs", "Modal", "Divider"])
        #expect(byCategory[.input] == ["Button", "TextField", "CheckBox", "ChoicePicker", "Slider", "DateTimeInput"])
    }

    @Test("category is metadata only — the rendered schema is unaffected")
    func categoryNotRendered() {
        let schema = ComponentSchema(name: "Text", category: .display, properties: [
            .required("text", .dynamicString, "The text content to display."),
        ])
        let rendered = SchemaRenderer.minify(SchemaRenderer.renderComponent(schema))
        #expect(!rendered.contains("\"category\""))
    }
}

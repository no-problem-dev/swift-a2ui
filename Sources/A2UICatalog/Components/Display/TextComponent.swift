import A2UICore

/// Displays a run of text, honoring simple Markdown but not HTML, images, or links.
///
/// `text` is a `DynamicString`, so it may be a literal, a data binding, or a `formatString` call —
/// A2UI has no string concatenation, so any interpolation goes through that function. `variant`
/// chooses only between `caption` and `body`; headings are written as Markdown.
public struct TextComponent: A2UIComponentProtocol, Codable, Sendable, Equatable {
    public static let componentName = "Text"

    private let component: String
    public let id: ComponentId
    public let accessibility: AccessibilityAttributes?
    public let weight: Double?
    public let catalogId: String?
    public let text: DynamicString
    public let variant: TextVariant?

    public init(
        id: ComponentId,
        text: DynamicString,
        variant: TextVariant? = nil,
        accessibility: AccessibilityAttributes? = nil,
        weight: Double? = nil,
        catalogId: String? = nil
    ) {
        self.component = Self.componentName
        self.id = id
        self.text = text
        self.variant = variant
        self.accessibility = accessibility
        self.weight = weight
        self.catalogId = catalogId
    }
}

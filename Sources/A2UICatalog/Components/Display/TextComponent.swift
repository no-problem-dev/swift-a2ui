import A2UICore

public struct TextComponent: A2UIComponentProtocol, Codable, Sendable, Equatable {
    public static let componentName = "Text"

    private let component: String
    public let id: ComponentId
    public let accessibility: AccessibilityAttributes?
    public let weight: Double?
    public let text: DynamicString
    public let variant: TextVariant?

    public init(
        id: ComponentId,
        text: DynamicString,
        variant: TextVariant? = nil,
        accessibility: AccessibilityAttributes? = nil,
        weight: Double? = nil
    ) {
        self.component = Self.componentName
        self.id = id
        self.text = text
        self.variant = variant
        self.accessibility = accessibility
        self.weight = weight
    }
}

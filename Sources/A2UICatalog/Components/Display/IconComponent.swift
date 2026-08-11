import A2UICore

/// Displays the single icon named by `name`.
///
/// `name` is more than a preset string: `IconNameValue` also accepts a custom SVG path or a data
/// binding, which is how a surface swaps `play` for `pause` from the data model. There is no size
/// or color property — the renderer decides both from context.
public struct IconComponent: A2UIComponentProtocol, Codable, Sendable, Equatable {
    public static let componentName = "Icon"

    private let component: String
    public let id: ComponentId
    public let accessibility: AccessibilityAttributes?
    public let weight: Double?
    public let catalogId: String?
    public let name: IconNameValue

    public init(
        id: ComponentId,
        name: IconNameValue,
        accessibility: AccessibilityAttributes? = nil,
        weight: Double? = nil,
        catalogId: String? = nil
    ) {
        self.component = Self.componentName
        self.id = id
        self.name = name
        self.accessibility = accessibility
        self.weight = weight
        self.catalogId = catalogId
    }
}

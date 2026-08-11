import A2UICore

/// Wraps exactly one child in a card container.
///
/// `child` is a single component ID. To put several things in a card, wrap them in a `Column` or
/// `Row` and pass that container's ID; several IDs, or an ID that does not exist on the surface,
/// are both invalid.
public struct CardComponent: A2UIComponentProtocol, Codable, Sendable, Equatable {
    public static let componentName = "Card"

    private let component: String
    public let id: ComponentId
    public let accessibility: AccessibilityAttributes?
    public let weight: Double?
    public let catalogId: String?
    public let child: ComponentId

    public init(
        id: ComponentId,
        child: ComponentId,
        accessibility: AccessibilityAttributes? = nil,
        weight: Double? = nil,
        catalogId: String? = nil
    ) {
        self.component = Self.componentName
        self.id = id
        self.child = child
        self.accessibility = accessibility
        self.weight = weight
        self.catalogId = catalogId
    }
}

import A2UICore

/// Presents `content` over the surface when `trigger` is interacted with.
///
/// Both are IDs of components declared elsewhere on the surface, so the trigger — usually a
/// `Button` — is an ordinary component the modal borrows rather than owns. There is no open/closed
/// property: visibility follows the interaction, not the data model.
public struct ModalComponent: A2UIComponentProtocol, Codable, Sendable, Equatable {
    public static let componentName = "Modal"

    private let component: String
    public let id: ComponentId
    public let accessibility: AccessibilityAttributes?
    public let weight: Double?
    public let catalogId: String?
    public let trigger: ComponentId
    public let content: ComponentId

    public init(
        id: ComponentId,
        trigger: ComponentId,
        content: ComponentId,
        accessibility: AccessibilityAttributes? = nil,
        weight: Double? = nil,
        catalogId: String? = nil
    ) {
        self.component = Self.componentName
        self.id = id
        self.trigger = trigger
        self.content = content
        self.accessibility = accessibility
        self.weight = weight
        self.catalogId = catalogId
    }
}

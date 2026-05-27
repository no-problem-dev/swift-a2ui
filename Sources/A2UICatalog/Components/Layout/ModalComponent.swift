import A2UICore

public struct ModalComponent: A2UIComponentProtocol, Codable, Sendable, Equatable {
    public static let componentName = "Modal"

    private let component: String
    public let id: ComponentId
    public let accessibility: AccessibilityAttributes?
    public let weight: Double?
    public let trigger: ComponentId
    public let content: ComponentId

    public init(
        id: ComponentId,
        trigger: ComponentId,
        content: ComponentId,
        accessibility: AccessibilityAttributes? = nil,
        weight: Double? = nil
    ) {
        self.component = Self.componentName
        self.id = id
        self.trigger = trigger
        self.content = content
        self.accessibility = accessibility
        self.weight = weight
    }
}

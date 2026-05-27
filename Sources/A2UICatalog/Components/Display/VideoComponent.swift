import A2UICore

public struct VideoComponent: A2UIComponentProtocol, Codable, Sendable, Equatable {
    public static let componentName = "Video"

    private let component: String
    public let id: ComponentId
    public let accessibility: AccessibilityAttributes?
    public let weight: Double?
    public let url: DynamicString

    public init(
        id: ComponentId,
        url: DynamicString,
        accessibility: AccessibilityAttributes? = nil,
        weight: Double? = nil
    ) {
        self.component = Self.componentName
        self.id = id
        self.url = url
        self.accessibility = accessibility
        self.weight = weight
    }
}

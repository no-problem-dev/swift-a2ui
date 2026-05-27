import A2UICore

public struct AudioPlayerComponent: A2UIComponentProtocol, Codable, Sendable, Equatable {
    public static let componentName = "AudioPlayer"

    private let component: String
    public let id: ComponentId
    public let accessibility: AccessibilityAttributes?
    public let weight: Double?
    public let url: DynamicString
    public let componentDescription: DynamicString?

    private enum CodingKeys: String, CodingKey {
        case component, id, accessibility, weight, url
        case componentDescription = "description"
    }

    public init(
        id: ComponentId,
        url: DynamicString,
        description: DynamicString? = nil,
        accessibility: AccessibilityAttributes? = nil,
        weight: Double? = nil
    ) {
        self.component = Self.componentName
        self.id = id
        self.url = url
        self.componentDescription = description
        self.accessibility = accessibility
        self.weight = weight
    }
}

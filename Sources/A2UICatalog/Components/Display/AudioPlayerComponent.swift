import A2UICore

/// Shows a player for the audio at `url`.
///
/// The accompanying description is a title or summary for the track; it is `componentDescription`
/// in Swift but encodes as `description` on the wire. Both fields are `DynamicString`s, so a list
/// of tracks can bind them per item.
public struct AudioPlayerComponent: A2UIComponentProtocol, Codable, Sendable, Equatable {
    public static let componentName = "AudioPlayer"

    private let component: String
    public let id: ComponentId
    public let accessibility: AccessibilityAttributes?
    public let weight: Double?
    public let catalogId: String?
    public let url: DynamicString
    public let componentDescription: DynamicString?

    private enum CodingKeys: String, CodingKey {
        case component, id, accessibility, weight, catalogId, url
        case componentDescription = "description"
    }

    public init(
        id: ComponentId,
        url: DynamicString,
        description: DynamicString? = nil,
        accessibility: AccessibilityAttributes? = nil,
        weight: Double? = nil,
        catalogId: String? = nil
    ) {
        self.component = Self.componentName
        self.id = id
        self.url = url
        self.componentDescription = description
        self.accessibility = accessibility
        self.weight = weight
        self.catalogId = catalogId
    }
}

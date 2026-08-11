import A2UICore

/// Plays the video at `url`, showing `posterUrl` until playback starts.
///
/// Both are `DynamicString`s and can be bound to the data model. The catalog declares no playback
/// properties, so a model cannot ask for autoplay, looping, or muting; the renderer decides.
public struct VideoComponent: A2UIComponentProtocol, Codable, Sendable, Equatable {
    public static let componentName = "Video"

    private let component: String
    public let id: ComponentId
    public let accessibility: AccessibilityAttributes?
    public let weight: Double?
    public let catalogId: String?
    public let url: DynamicString
    public let posterUrl: DynamicString?

    public init(
        id: ComponentId,
        url: DynamicString,
        posterUrl: DynamicString? = nil,
        accessibility: AccessibilityAttributes? = nil,
        weight: Double? = nil,
        catalogId: String? = nil
    ) {
        self.component = Self.componentName
        self.id = id
        self.url = url
        self.posterUrl = posterUrl
        self.accessibility = accessibility
        self.weight = weight
        self.catalogId = catalogId
    }
}

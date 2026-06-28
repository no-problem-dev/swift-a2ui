import A2UICore

/// 動画再生コンポーネント。指定した URL の動画を表示する。
public struct VideoComponent: A2UIComponentProtocol, Codable, Sendable, Equatable {
    public static let componentName = "Video"

    private let component: String
    public let id: ComponentId
    public let accessibility: AccessibilityAttributes?
    public let weight: Double?
    public let url: DynamicString
    public let posterUrl: DynamicString?

    public init(
        id: ComponentId,
        url: DynamicString,
        posterUrl: DynamicString? = nil,
        accessibility: AccessibilityAttributes? = nil,
        weight: Double? = nil
    ) {
        self.component = Self.componentName
        self.id = id
        self.url = url
        self.posterUrl = posterUrl
        self.accessibility = accessibility
        self.weight = weight
    }
}

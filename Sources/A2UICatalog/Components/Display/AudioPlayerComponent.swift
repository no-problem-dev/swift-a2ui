import A2UICore

/// 音声再生コンポーネント。指定した URL の音声を再生するプレーヤーを表示する。
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

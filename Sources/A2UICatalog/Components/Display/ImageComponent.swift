import A2UICore

/// 画像コンポーネント。指定した URL の画像を表示する。
public struct ImageComponent: A2UIComponentProtocol, Codable, Sendable, Equatable {
    public static let componentName = "Image"

    private let component: String
    public let id: ComponentId
    public let accessibility: AccessibilityAttributes?
    public let weight: Double?
    public let url: DynamicString
    public let imageDescription: DynamicString?
    public let fit: ImageFit?
    public let variant: ImageVariant?

    private enum CodingKeys: String, CodingKey {
        case component, id, accessibility, weight, url, fit, variant
        case imageDescription = "description"
    }

    public init(
        id: ComponentId,
        url: DynamicString,
        description: DynamicString? = nil,
        fit: ImageFit? = nil,
        variant: ImageVariant? = nil,
        accessibility: AccessibilityAttributes? = nil,
        weight: Double? = nil
    ) {
        self.component = Self.componentName
        self.id = id
        self.url = url
        self.imageDescription = description
        self.fit = fit
        self.variant = variant
        self.accessibility = accessibility
        self.weight = weight
    }
}

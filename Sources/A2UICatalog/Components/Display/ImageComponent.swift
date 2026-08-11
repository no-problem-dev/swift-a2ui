import A2UICore

/// Displays a remote image, sized by `variant` and scaled inside that box by `fit`.
///
/// `url` and the accessibility text are `DynamicString`s, so a template child can bind them to the
/// item it is rendering. The accessibility text is `imageDescription` in Swift but encodes as
/// `description` on the wire.
public struct ImageComponent: A2UIComponentProtocol, Codable, Sendable, Equatable {
    public static let componentName = "Image"

    private let component: String
    public let id: ComponentId
    public let accessibility: AccessibilityAttributes?
    public let weight: Double?
    public let catalogId: String?
    public let url: DynamicString
    public let imageDescription: DynamicString?
    public let fit: ImageFit?
    public let variant: ImageVariant?

    private enum CodingKeys: String, CodingKey {
        case component, id, accessibility, weight, catalogId, url, fit, variant
        case imageDescription = "description"
    }

    public init(
        id: ComponentId,
        url: DynamicString,
        description: DynamicString? = nil,
        fit: ImageFit? = nil,
        variant: ImageVariant? = nil,
        accessibility: AccessibilityAttributes? = nil,
        weight: Double? = nil,
        catalogId: String? = nil
    ) {
        self.component = Self.componentName
        self.id = id
        self.url = url
        self.imageDescription = description
        self.fit = fit
        self.variant = variant
        self.accessibility = accessibility
        self.weight = weight
        self.catalogId = catalogId
    }
}

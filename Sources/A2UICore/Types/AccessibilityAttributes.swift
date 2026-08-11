/// What a component tells assistive technology about itself.
///
/// The wire key is `description`, but the property is named `accessibilityDescription` so it does
/// not shadow the `description` every Swift value already has. The initializer still takes
/// `description:`, so only the property read differs from the JSON.
public struct AccessibilityAttributes: Codable, Sendable, Equatable {
    public let label: DynamicString?
    public let accessibilityDescription: DynamicString?

    public init(label: DynamicString? = nil, description: DynamicString? = nil) {
        self.label = label
        self.accessibilityDescription = description
    }

    // Map "description" JSON key to avoid shadowing Swift's description property
    private enum CodingKeys: String, CodingKey {
        case label
        case accessibilityDescription = "description"
    }
}

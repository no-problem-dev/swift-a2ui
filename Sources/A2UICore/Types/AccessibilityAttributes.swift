/// コンポーネントのアクセシビリティ情報。
///
/// JSON キー名の衝突を避けるため、`description` は `accessibilityDescription` にマッピングする。
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

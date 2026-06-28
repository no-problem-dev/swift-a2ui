import A2UICore

/// アイコンコンポーネント。`name` で指定したアイコンを表示する。
public struct IconComponent: A2UIComponentProtocol, Codable, Sendable, Equatable {
    public static let componentName = "Icon"

    private let component: String
    public let id: ComponentId
    public let accessibility: AccessibilityAttributes?
    public let weight: Double?
    public let name: IconNameValue

    public init(
        id: ComponentId,
        name: IconNameValue,
        accessibility: AccessibilityAttributes? = nil,
        weight: Double? = nil
    ) {
        self.component = Self.componentName
        self.id = id
        self.name = name
        self.accessibility = accessibility
        self.weight = weight
    }
}

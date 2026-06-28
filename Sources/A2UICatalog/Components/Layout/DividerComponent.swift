import A2UICore

/// 区切り線コンポーネント。水平または垂直の仕切りを表示する。
public struct DividerComponent: A2UIComponentProtocol, Codable, Sendable, Equatable {
    public static let componentName = "Divider"

    private let component: String
    public let id: ComponentId
    public let accessibility: AccessibilityAttributes?
    public let weight: Double?
    public let axis: DividerAxis?

    public init(
        id: ComponentId,
        axis: DividerAxis? = nil,
        accessibility: AccessibilityAttributes? = nil,
        weight: Double? = nil
    ) {
        self.component = Self.componentName
        self.id = id
        self.axis = axis
        self.accessibility = accessibility
        self.weight = weight
    }
}

import A2UICore

/// ボタンコンポーネント。タップすると `action` を実行する。
public struct ButtonComponent: A2UIComponentProtocol, Codable, Sendable, Equatable {
    public static let componentName = "Button"

    private let component: String
    public let id: ComponentId
    public let accessibility: AccessibilityAttributes?
    public let weight: Double?
    public let child: ComponentId
    public let action: Action
    public let variant: ButtonVariant?
    public let checks: [CheckRule]?

    public init(
        id: ComponentId,
        child: ComponentId,
        action: Action,
        variant: ButtonVariant? = nil,
        checks: [CheckRule]? = nil,
        accessibility: AccessibilityAttributes? = nil,
        weight: Double? = nil
    ) {
        self.component = Self.componentName
        self.id = id
        self.child = child
        self.action = action
        self.variant = variant
        self.checks = checks
        self.accessibility = accessibility
        self.weight = weight
    }
}

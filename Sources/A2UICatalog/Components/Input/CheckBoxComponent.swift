import A2UICore

/// チェックボックスコンポーネント。ラベル付きのオン/オフ入力。
public struct CheckBoxComponent: A2UIComponentProtocol, Codable, Sendable, Equatable {
    public static let componentName = "CheckBox"

    private let component: String
    public let id: ComponentId
    public let accessibility: AccessibilityAttributes?
    public let weight: Double?
    public let label: DynamicString
    public let value: DynamicBoolean
    public let checks: [CheckRule]?

    public init(
        id: ComponentId,
        label: DynamicString,
        value: DynamicBoolean,
        checks: [CheckRule]? = nil,
        accessibility: AccessibilityAttributes? = nil,
        weight: Double? = nil
    ) {
        self.component = Self.componentName
        self.id = id
        self.label = label
        self.value = value
        self.checks = checks
        self.accessibility = accessibility
        self.weight = weight
    }
}

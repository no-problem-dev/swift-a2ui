import A2UICore

public struct TextFieldComponent: A2UIComponentProtocol, Codable, Sendable, Equatable {
    public static let componentName = "TextField"

    private let component: String
    public let id: ComponentId
    public let accessibility: AccessibilityAttributes?
    public let weight: Double?
    public let label: DynamicString
    public let value: DynamicString?
    public let variant: TextFieldVariant?
    public let placeholder: DynamicString?
    public let checks: [CheckRule]?

    public init(
        id: ComponentId,
        label: DynamicString,
        value: DynamicString? = nil,
        variant: TextFieldVariant? = nil,
        placeholder: DynamicString? = nil,
        checks: [CheckRule]? = nil,
        accessibility: AccessibilityAttributes? = nil,
        weight: Double? = nil
    ) {
        self.component = Self.componentName
        self.id = id
        self.label = label
        self.value = value
        self.variant = variant
        self.placeholder = placeholder
        self.checks = checks
        self.accessibility = accessibility
        self.weight = weight
    }
}

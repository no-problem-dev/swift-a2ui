import A2UICore

public struct ChoiceOption: Codable, Sendable, Equatable {
    public let label: DynamicString
    public let value: String

    public init(label: DynamicString, value: String) {
        self.label = label
        self.value = value
    }
}

public struct ChoicePickerComponent: A2UIComponentProtocol, Codable, Sendable, Equatable {
    public static let componentName = "ChoicePicker"

    private let component: String
    public let id: ComponentId
    public let accessibility: AccessibilityAttributes?
    public let weight: Double?
    public let options: [ChoiceOption]
    public let value: DynamicStringList
    public let label: DynamicString?
    public let variant: ChoicePickerVariant?
    public let displayStyle: ChoicePickerDisplayStyle?
    public let filterable: Bool?
    public let checks: [CheckRule]?

    public init(
        id: ComponentId,
        options: [ChoiceOption],
        value: DynamicStringList,
        label: DynamicString? = nil,
        variant: ChoicePickerVariant? = nil,
        displayStyle: ChoicePickerDisplayStyle? = nil,
        filterable: Bool? = nil,
        checks: [CheckRule]? = nil,
        accessibility: AccessibilityAttributes? = nil,
        weight: Double? = nil
    ) {
        self.component = Self.componentName
        self.id = id
        self.options = options
        self.value = value
        self.label = label
        self.variant = variant
        self.displayStyle = displayStyle
        self.filterable = filterable
        self.checks = checks
        self.accessibility = accessibility
        self.weight = weight
    }
}

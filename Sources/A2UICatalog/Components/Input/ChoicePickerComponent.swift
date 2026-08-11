import A2UICore

/// One entry of a `ChoicePicker`: the label shown to the user, and the stable string written into
/// the picker's `value` when it is chosen. The label may be bound; the value is a plain string.
public struct ChoiceOption: Codable, Sendable, Equatable {
    public let label: DynamicString
    public let value: String

    public init(label: DynamicString, value: String) {
        self.label = label
        self.value = value
    }
}

/// Selects one or more options from a list.
///
/// `value` is a list of strings even when `variant` is `mutuallyExclusive`, so the data model has
/// to hold an array either way. `displayStyle` decides between checkboxes and chips, and
/// `filterable` adds a search field over the options.
public struct ChoicePickerComponent: A2UIComponentProtocol, Codable, Sendable, Equatable {
    public static let componentName = "ChoicePicker"

    private let component: String
    public let id: ComponentId
    public let accessibility: AccessibilityAttributes?
    public let weight: Double?
    public let catalogId: String?
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
        weight: Double? = nil,
        catalogId: String? = nil
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
        self.catalogId = catalogId
    }
}

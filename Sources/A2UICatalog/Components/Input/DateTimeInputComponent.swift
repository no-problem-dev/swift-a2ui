import A2UICore

public struct DateTimeInputComponent: A2UIComponentProtocol, Codable, Sendable, Equatable {
    public static let componentName = "DateTimeInput"

    private let component: String
    public let id: ComponentId
    public let accessibility: AccessibilityAttributes?
    public let weight: Double?
    public let value: DynamicString
    public let enableDate: Bool?
    public let enableTime: Bool?
    public let min: DynamicString?
    public let max: DynamicString?
    public let label: DynamicString?
    public let checks: [CheckRule]?

    public init(
        id: ComponentId,
        value: DynamicString,
        enableDate: Bool? = nil,
        enableTime: Bool? = nil,
        min: DynamicString? = nil,
        max: DynamicString? = nil,
        label: DynamicString? = nil,
        checks: [CheckRule]? = nil,
        accessibility: AccessibilityAttributes? = nil,
        weight: Double? = nil
    ) {
        self.component = Self.componentName
        self.id = id
        self.value = value
        self.enableDate = enableDate
        self.enableTime = enableTime
        self.min = min
        self.max = max
        self.label = label
        self.checks = checks
        self.accessibility = accessibility
        self.weight = weight
    }
}

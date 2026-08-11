import A2UICore

/// Collects a date, a time, or both, as an ISO 8601 string in `value`.
///
/// `enableDate` and `enableTime` both default to false, so at least one has to be turned on for
/// the control to be usable. `value` is required: when nothing is chosen yet, initialize it with
/// an empty string rather than omitting it. `min` and `max` accept a literal in `date`, `time`, or
/// `date-time` format, or a binding.
public struct DateTimeInputComponent: A2UIComponentProtocol, Codable, Sendable, Equatable {
    public static let componentName = "DateTimeInput"

    private let component: String
    public let id: ComponentId
    public let accessibility: AccessibilityAttributes?
    public let weight: Double?
    public let catalogId: String?
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
        weight: Double? = nil,
        catalogId: String? = nil
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
        self.catalogId = catalogId
    }
}

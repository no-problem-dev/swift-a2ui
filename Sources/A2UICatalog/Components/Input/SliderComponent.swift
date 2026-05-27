import A2UICore

public struct SliderComponent: A2UIComponentProtocol, Codable, Sendable, Equatable {
    public static let componentName = "Slider"

    private let component: String
    public let id: ComponentId
    public let accessibility: AccessibilityAttributes?
    public let weight: Double?
    public let value: DynamicNumber
    public let max: Double
    public let label: DynamicString?
    public let min: Double?
    public let checks: [CheckRule]?

    public init(
        id: ComponentId,
        value: DynamicNumber,
        max: Double,
        label: DynamicString? = nil,
        min: Double? = nil,
        checks: [CheckRule]? = nil,
        accessibility: AccessibilityAttributes? = nil,
        weight: Double? = nil
    ) {
        self.component = Self.componentName
        self.id = id
        self.value = value
        self.max = max
        self.label = label
        self.min = min
        self.checks = checks
        self.accessibility = accessibility
        self.weight = weight
    }
}

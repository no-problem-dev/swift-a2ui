import A2UICore

/// Picks a number between `min` and `max` by dragging.
///
/// `max` is required and `min` defaults to 0. With `steps` the slider snaps to that many discrete
/// divisions; without it, it moves continuously. Only `value` is bindable — the bounds are plain
/// numbers, so a range that depends on data cannot be expressed here.
public struct SliderComponent: A2UIComponentProtocol, Codable, Sendable, Equatable {
    public static let componentName = "Slider"

    private let component: String
    public let id: ComponentId
    public let accessibility: AccessibilityAttributes?
    public let weight: Double?
    public let catalogId: String?
    public let value: DynamicNumber
    public let max: Double
    public let label: DynamicString?
    public let min: Double?
    public let steps: Int?
    public let checks: [CheckRule]?

    public init(
        id: ComponentId,
        value: DynamicNumber,
        max: Double,
        label: DynamicString? = nil,
        min: Double? = nil,
        steps: Int? = nil,
        checks: [CheckRule]? = nil,
        accessibility: AccessibilityAttributes? = nil,
        weight: Double? = nil,
        catalogId: String? = nil
    ) {
        self.component = Self.componentName
        self.id = id
        self.value = value
        self.max = max
        self.label = label
        self.min = min
        self.steps = steps
        self.checks = checks
        self.accessibility = accessibility
        self.weight = weight
        self.catalogId = catalogId
    }
}

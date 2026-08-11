import A2UICore

/// A labeled on/off control bound to a boolean in the data model.
///
/// `value` is required, so the initial state is always stated — there is no third, unset state.
/// `checks` run against that value, which is how a must-be-accepted box is expressed.
public struct CheckBoxComponent: A2UIComponentProtocol, Codable, Sendable, Equatable {
    public static let componentName = "CheckBox"

    private let component: String
    public let id: ComponentId
    public let accessibility: AccessibilityAttributes?
    public let weight: Double?
    public let catalogId: String?
    public let label: DynamicString
    public let value: DynamicBoolean
    public let checks: [CheckRule]?

    public init(
        id: ComponentId,
        label: DynamicString,
        value: DynamicBoolean,
        checks: [CheckRule]? = nil,
        accessibility: AccessibilityAttributes? = nil,
        weight: Double? = nil,
        catalogId: String? = nil
    ) {
        self.component = Self.componentName
        self.id = id
        self.label = label
        self.value = value
        self.checks = checks
        self.accessibility = accessibility
        self.weight = weight
        self.catalogId = catalogId
    }
}

import A2UICore

/// Runs `action` when tapped, either raising an event to the agent or calling a catalog function.
///
/// The label is a child component referenced by ID — a `Text` for a labeled button, an `Icon` only
/// when an icon-only button was asked for. `checks` are the validation rules evaluated before the
/// action fires; their failure messages belong inside the check, not in a separate text component.
/// `variant` marks the main call to action (`primary`) or drops the border and background so the
/// child reads as a link (`borderless`).
public struct ButtonComponent: A2UIComponentProtocol, Codable, Sendable, Equatable {
    public static let componentName = "Button"

    private let component: String
    public let id: ComponentId
    public let accessibility: AccessibilityAttributes?
    public let weight: Double?
    public let catalogId: String?
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
        weight: Double? = nil,
        catalogId: String? = nil
    ) {
        self.component = Self.componentName
        self.id = id
        self.child = child
        self.action = action
        self.variant = variant
        self.checks = checks
        self.accessibility = accessibility
        self.weight = weight
        self.catalogId = catalogId
    }
}

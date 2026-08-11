import A2UICore

/// Draws a rule between siblings, horizontal unless `axis` says otherwise.
///
/// It takes no children and exposes no thickness or color; a `horizontal` divider belongs between
/// the children of a `Column`, a `vertical` one between the children of a `Row`.
public struct DividerComponent: A2UIComponentProtocol, Codable, Sendable, Equatable {
    public static let componentName = "Divider"

    private let component: String
    public let id: ComponentId
    public let accessibility: AccessibilityAttributes?
    public let weight: Double?
    public let catalogId: String?
    public let axis: DividerAxis?

    public init(
        id: ComponentId,
        axis: DividerAxis? = nil,
        accessibility: AccessibilityAttributes? = nil,
        weight: Double? = nil,
        catalogId: String? = nil
    ) {
        self.component = Self.componentName
        self.id = id
        self.axis = axis
        self.accessibility = accessibility
        self.weight = weight
        self.catalogId = catalogId
    }
}

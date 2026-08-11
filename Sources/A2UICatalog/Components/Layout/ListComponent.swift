import A2UICore

/// Lays its children out in one direction, vertically unless `direction` says otherwise.
///
/// The data-driven case is what this component is for: `children` can be a template that expands
/// one component over an array in the data model, so the agent declares the row once instead of
/// emitting a component per item. `align` positions items across the direction of travel.
public struct ListComponent: A2UIComponentProtocol, Codable, Sendable, Equatable {
    public static let componentName = "List"

    private let component: String
    public let id: ComponentId
    public let accessibility: AccessibilityAttributes?
    public let weight: Double?
    public let catalogId: String?
    public let children: ChildList
    public let direction: ListDirection?
    public let align: LayoutAlign?

    public init(
        id: ComponentId,
        children: ChildList,
        direction: ListDirection? = nil,
        align: LayoutAlign? = nil,
        accessibility: AccessibilityAttributes? = nil,
        weight: Double? = nil,
        catalogId: String? = nil
    ) {
        self.component = Self.componentName
        self.id = id
        self.children = children
        self.direction = direction
        self.align = align
        self.accessibility = accessibility
        self.weight = weight
        self.catalogId = catalogId
    }
}

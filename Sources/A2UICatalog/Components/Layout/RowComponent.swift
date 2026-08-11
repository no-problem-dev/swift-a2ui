import A2UICore

/// Arranges its children horizontally.
///
/// `children` is a fixed list of component IDs or a template expanded over a data path; children
/// are always referred to by ID and can never be declared inline. `justify` spreads them along the
/// horizontal axis and `align` positions them vertically. Nest `Column`s inside to build a grid.
public struct RowComponent: A2UIComponentProtocol, Codable, Sendable, Equatable {
    public static let componentName = "Row"

    private let component: String
    public let id: ComponentId
    public let accessibility: AccessibilityAttributes?
    public let weight: Double?
    public let catalogId: String?
    public let children: ChildList
    public let justify: LayoutJustify?
    public let align: LayoutAlign?

    public init(
        id: ComponentId,
        children: ChildList,
        justify: LayoutJustify? = nil,
        align: LayoutAlign? = nil,
        accessibility: AccessibilityAttributes? = nil,
        weight: Double? = nil,
        catalogId: String? = nil
    ) {
        self.component = Self.componentName
        self.id = id
        self.children = children
        self.justify = justify
        self.align = align
        self.accessibility = accessibility
        self.weight = weight
        self.catalogId = catalogId
    }
}

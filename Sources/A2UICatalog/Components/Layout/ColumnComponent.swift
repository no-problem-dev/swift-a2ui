import A2UICore

public struct ColumnComponent: A2UIComponentProtocol, Codable, Sendable, Equatable {
    public static let componentName = "Column"

    private let component: String
    public let id: ComponentId
    public let accessibility: AccessibilityAttributes?
    public let weight: Double?
    public let children: ChildList
    public let justify: LayoutJustify?
    public let align: LayoutAlign?

    public init(
        id: ComponentId,
        children: ChildList,
        justify: LayoutJustify? = nil,
        align: LayoutAlign? = nil,
        accessibility: AccessibilityAttributes? = nil,
        weight: Double? = nil
    ) {
        self.component = Self.componentName
        self.id = id
        self.children = children
        self.justify = justify
        self.align = align
        self.accessibility = accessibility
        self.weight = weight
    }
}

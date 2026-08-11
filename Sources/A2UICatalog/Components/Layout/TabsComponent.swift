import A2UICore

/// One entry of a `Tabs` component: the title drawn on the tab, and the ID of the component
/// revealed when it is selected.
public struct TabItem: Codable, Sendable, Equatable {
    public let title: DynamicString
    public let child: ComponentId

    public init(title: DynamicString, child: ComponentId) {
        self.title = title
        self.child = child
    }
}

/// Shows one of several children at a time, selected by its tab.
///
/// `tabs` must hold at least one entry, and each entry points at a single component by ID — put a
/// `Column` behind a tab to show more than one thing. Which tab is selected lives in the renderer,
/// not in the data model.
public struct TabsComponent: A2UIComponentProtocol, Codable, Sendable, Equatable {
    public static let componentName = "Tabs"

    private let component: String
    public let id: ComponentId
    public let accessibility: AccessibilityAttributes?
    public let weight: Double?
    public let catalogId: String?
    public let tabs: [TabItem]

    public init(
        id: ComponentId,
        tabs: [TabItem],
        accessibility: AccessibilityAttributes? = nil,
        weight: Double? = nil,
        catalogId: String? = nil
    ) {
        self.component = Self.componentName
        self.id = id
        self.tabs = tabs
        self.accessibility = accessibility
        self.weight = weight
        self.catalogId = catalogId
    }
}

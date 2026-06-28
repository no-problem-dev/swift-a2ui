import A2UICore

/// タブの 1 項目。タイトルと子コンポーネント ID を持つ。
public struct TabItem: Codable, Sendable, Equatable {
    public let title: DynamicString
    public let child: ComponentId

    public init(title: DynamicString, child: ComponentId) {
        self.title = title
        self.child = child
    }
}

/// タブコンポーネント。複数のタブを切り替えて表示する。
public struct TabsComponent: A2UIComponentProtocol, Codable, Sendable, Equatable {
    public static let componentName = "Tabs"

    private let component: String
    public let id: ComponentId
    public let accessibility: AccessibilityAttributes?
    public let weight: Double?
    public let tabs: [TabItem]

    public init(
        id: ComponentId,
        tabs: [TabItem],
        accessibility: AccessibilityAttributes? = nil,
        weight: Double? = nil
    ) {
        self.component = Self.componentName
        self.id = id
        self.tabs = tabs
        self.accessibility = accessibility
        self.weight = weight
    }
}

import A2UICore

/// カードコンポーネント。単一の子コンポーネントをカードスタイルのコンテナで囲む。
public struct CardComponent: A2UIComponentProtocol, Codable, Sendable, Equatable {
    public static let componentName = "Card"

    private let component: String
    public let id: ComponentId
    public let accessibility: AccessibilityAttributes?
    public let weight: Double?
    public let catalogId: String?
    public let child: ComponentId

    public init(
        id: ComponentId,
        child: ComponentId,
        accessibility: AccessibilityAttributes? = nil,
        weight: Double? = nil,
        catalogId: String? = nil
    ) {
        self.component = Self.componentName
        self.id = id
        self.child = child
        self.accessibility = accessibility
        self.weight = weight
        self.catalogId = catalogId
    }
}

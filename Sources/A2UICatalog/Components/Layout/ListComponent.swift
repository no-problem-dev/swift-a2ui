import A2UICore

/// リストコンポーネント。子コンポーネントを縦または横方向に並べる。
/// テンプレート子リストによるデータドリブンなリスト生成もサポートする。
public struct ListComponent: A2UIComponentProtocol, Codable, Sendable, Equatable {
    public static let componentName = "List"

    private let component: String
    public let id: ComponentId
    public let accessibility: AccessibilityAttributes?
    public let weight: Double?
    public let children: ChildList
    public let direction: ListDirection?
    public let align: LayoutAlign?

    public init(
        id: ComponentId,
        children: ChildList,
        direction: ListDirection? = nil,
        align: LayoutAlign? = nil,
        accessibility: AccessibilityAttributes? = nil,
        weight: Double? = nil
    ) {
        self.component = Self.componentName
        self.id = id
        self.children = children
        self.direction = direction
        self.align = align
        self.accessibility = accessibility
        self.weight = weight
    }
}

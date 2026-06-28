import A2UICore

/// 解決済みコンポーネントツリーの 1 ノード。
public struct ComponentNode: Sendable, Equatable {
    /// コンポーネントの一意識別子。
    public let id: String
    /// コンポーネントの生データ。
    public let component: StructuredValue
    /// 解決済みの子ノード。
    public var children: [ComponentNode]

    public init(id: String, component: StructuredValue, children: [ComponentNode] = []) {
        self.id = id
        self.component = component
        self.children = children
    }
}

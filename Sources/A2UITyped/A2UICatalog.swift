import A2UICore

/// コンシューマーが注入する**カタログ**型プロトコル。レンダラーが描画できるコンポーネントの集合をコンパイル時に確定する。
///
/// A2UI の拡張モデルは「クライアントが信頼するコンポーネントのカタログを持ち、
/// エージェントはその中のものだけリクエストできる」という思想。
/// ライブラリは `BasicCatalog` を同梱する。アプリケーションは `CombinedNode` でこれと
/// 独自の Design System コンポーネントを組み合わせる
/// （例: `enum AppCatalog: A2UICatalog { typealias Node = CombinedNode<MyNode, BasicComponent>; ... }`）。
///
/// レンダラーはこのプロトコルを型パラメータとして受け取る（`A2UIRenderer<some A2UICatalog>`）。
/// ディスパッチはコンパイル時に全ケースを網羅しながらも、コンシューマーによる型レベルの拡張を受け入れる。
public protocol A2UICatalog: Sendable {
    /// このカタログがレンダリングできるコンポーネントの closed sum 型。
    associatedtype Node: ComponentNode

    /// A2UI の `catalogId` と一致するカノニカルな識別子 URI。
    static var catalogId: String { get }
}

/// 2 つのノード型を合成し、`component` 名に基づいて各カタログへルーティングする。
///
/// `Primary` が名前衝突に優先するため、コンシューマーは Basic コンポーネントを自前実装で上書きできる。
/// ライブラリは `Fallback` に Basic ノードを配置することで網羅性を保持する。
/// コンシューマーは Basic ノード全体を埋め込むだけでよく、個別ケースを再列挙する必要はない。
public enum CombinedNode<Primary: ComponentNode, Fallback: ComponentNode>: ComponentNode {
    case primary(Primary)
    case fallback(Fallback)

    public static var componentNames: Set<String> {
        Primary.componentNames.union(Fallback.componentNames)
    }

    public var id: ComponentId {
        switch self {
        case .primary(let node): return node.id
        case .fallback(let node): return node.id
        }
    }

    public var componentName: String {
        switch self {
        case .primary(let node): return node.componentName
        case .fallback(let node): return node.componentName
        }
    }

    private enum Keys: String, CodingKey { case component }

    public init(from decoder: Decoder) throws {
        let name = try decoder.container(keyedBy: Keys.self).decode(String.self, forKey: .component)
        if Primary.componentNames.contains(name) {
            self = .primary(try Primary(from: decoder))
        } else {
            // Fallback owns the rest (and throws if it, too, does not handle the name).
            self = .fallback(try Fallback(from: decoder))
        }
    }
}

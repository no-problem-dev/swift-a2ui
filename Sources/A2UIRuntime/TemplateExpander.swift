import StructuredDataCore
import A2UICore
import A2UISurface
import Foundation

/// `ChildList` から生成された解決済み子スロット — View 層が再帰するために必要な情報。
///
/// `basePath` はこの子インスタンスのデータスコープ。静的リストの場合は親スコープと同一。
/// テンプレートインスタンスの場合は `/<path>/<index>`（またはオブジェクトなら `/<path>/<key>`）となり、
/// テンプレート内の相対バインドが正しい配列要素に解決される（仕様 §scope）。
public struct ResolvedChild: Sendable, Hashable {
    public let componentId: String
    public let basePath: String
    /// テンプレート反復の 0 始まりの添字。静的 `ids` リストでは `nil`。
    /// 組み込み `@index`（v1.0）はこの値を返す。
    public let collectionIndex: Int?

    public init(componentId: String, basePath: String, collectionIndex: Int? = nil) {
        self.componentId = componentId
        self.basePath = basePath
        self.collectionIndex = collectionIndex
    }
}

/// `ChildList` を具体的な子スロットへ展開し、A2UI のテンプレート / コレクションスコープ規則を適用する。
///
/// 仕様 §"Collection scopes (relative paths)":
/// - 静的 `ids` リスト → 各 id は親スコープを維持する。
/// - `template(componentId, path)` → 親スコープを起点に解決した `path` の配列（またはオブジェクト）を
///   反復し、要素ごとに子スコープでテンプレートをインスタンス化する。
public enum TemplateExpander {

    /// `context` 内で `ChildList` を展開する。`context.path` は親のスコープ。
    public static func expand(_ children: ChildList, in context: DataContext) -> [ResolvedChild] {
        switch children {
        case .ids(let ids):
            return ids.map { ResolvedChild(componentId: $0, basePath: context.path) }

        case .template(let componentId, let path):
            // Resolve the bound collection against the parent scope.
            let absolutePath = JSONPointer.absolutePath(path, scope: context.path)
            guard let value = context.dataModel.get(absolutePath) else {
                return []  // progressive rendering: data not yet arrived
            }
            switch value {
            case .array(let items):
                return items.indices.map { index in
                    ResolvedChild(
                        componentId: componentId,
                        basePath: "\(absolutePath)/\(index)",
                        collectionIndex: index
                    )
                }
            case .object(let dict):
                // Iterate object keys in a stable (sorted) order.
                return dict.keys.sorted().enumerated().map { offset, key in
                    ResolvedChild(
                        componentId: componentId,
                        basePath: "\(absolutePath)/\(key)",
                        collectionIndex: offset
                    )
                }
            default:
                return []
            }
        }
    }

    /// 生の `children` プロパティ（`StructuredValue`）を `ChildList` にデコードして展開するユーティリティ。
    /// 有効な `ChildList` でない場合は nil を返す。
    public static func expandRaw(_ childrenProperty: StructuredValue, in context: DataContext) -> [ResolvedChild]? {
        guard let childList = decodeChildList(childrenProperty) else { return nil }
        return expand(childList, in: context)
    }

    private static func decodeChildList(_ value: StructuredValue) -> ChildList? {
        return try? value.decode(ChildList.self)
    }
}

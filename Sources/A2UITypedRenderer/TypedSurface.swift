import Foundation
import Observation
import A2UICore
import A2UISurface
import A2UITyped

/// 特定の `Catalog` に対応したレンダリング済みサーフェス: フラットな id → ノードマップとデータモデル。
///
/// A2UI のワイヤーモデルをミラーする（コンポーネントは id をキーとするフラットマップで、
/// 親は id 文字列で子を参照）— ライブストアは `[ComponentId: CatalogNode<Catalog.Node>]`、
/// 完全型付き・`any` なし。`@Observable` のため SwiftUI は 2 種の A2UI 部分更新で再描画する:
/// - `updateComponents`: `nodes` を変更（追跡対象）→ 構造を再描画。
/// - `updateDataModel`: 非 Observable の `DataModel` に書き込み `dataVersion` を加算（追跡対象）。
///   バインディング読み取りビューは `dataVersion` に依存するため再解決される
///   （粗い粒度だが正しい。パスごとの購読は将来の最適化）。
@MainActor
@Observable
public final class TypedSurface<Catalog: A2UICatalog>: Identifiable {
    /// サーフェス識別子（A2UI `surfaceId`）。単一サーフェス使用時は `rootId` に合わせる。
    public let id: String
    public let catalogId: String
    public let rootId: ComponentId
    public let dataModel: DataModel
    /// ホストのユーザーイベントシンク（`Button` の `action.event` 等）: `(name, context, sourceComponentId)`。
    /// デフォルトは no-op。
    let onEvent: (String, [String: StructuredValue], ComponentId) -> Void

    private var nodes: [ComponentId: CatalogNode<Catalog.Node>]
    /// データモデルへの書き込みのたびに加算される。バインディング読み取りビューがリアクティビティのために依存する。
    private(set) var dataVersion = 0
    /// `updateComponents` バッチのたびに加算される。`A2UISurfaceView` がこれをアニメーション値にすることで、
    /// ストリーミングで流れ込むコンポーネントがポップではなくトランジション付きで現れる（カスケード組み上がり）。
    private(set) var structureVersion = 0

    public init(
        id: String? = nil,
        rootId: ComponentId = "root",
        nodes: [CatalogNode<Catalog.Node>],
        dataModel: DataModel = DataModel(),
        onEvent: @escaping (String, [String: StructuredValue], ComponentId) -> Void = { _, _, _ in }
    ) {
        self.id = id ?? rootId
        self.catalogId = Catalog.catalogId
        self.rootId = rootId
        self.dataModel = dataModel
        self.onEvent = onEvent
        self.nodes = Dictionary(nodes.map { ($0.id, $0) }, uniquingKeysWith: { _, new in new })
    }

    public func node(_ id: ComponentId) -> CatalogNode<Catalog.Node>? { nodes[id] }

    // MARK: - Partial updates (A2UI processing layer)

    /// `updateComponents` を適用する: id でアップサート。仕様に従い、既存 id に対する新しいノードは
    /// 丸ごと置き換える（コンポーネント型の変更も可）。辞書のアップサートで実現する。
    public func applyUpdateComponents(_ incoming: [CatalogNode<Catalog.Node>]) {
        for node in incoming { nodes[node.id] = node }
        structureVersion += 1
    }

    /// `updateDataModel` を適用する: JSON Pointer パスに値を書き込み、再解決をトリガーする。
    public func applyUpdateDataModel(path: String, value: StructuredValue?) {
        dataModel.set(path, value)
        touchData()
    }

    /// データバージョンを加算してバインディング読み取りビューを再解決させる（双方向入力書き込み時に使用）。
    func touchData() { dataVersion += 1 }

    // MARK: - Decoding

    /// A2UI の `updateComponents.components` 配列（各 `{id, component, ...}`）をノードへデコードする。
    /// 未知のコンポーネント名はエラーを投げず `.unknown` へ降格する（仕様のグレースフルハンドリング）。
    public static func decodeNodes(fromJSONArray data: Data) throws -> [CatalogNode<Catalog.Node>] {
        try JSONDecoder().decode([CatalogNode<Catalog.Node>].self, from: data)
    }
}

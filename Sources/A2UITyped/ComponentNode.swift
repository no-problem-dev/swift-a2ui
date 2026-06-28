import A2UICore

/// カタログの**ノード型**: そのカタログがデコード・描画できるコンポーネントの closed sum。
///
/// 文字列型の `ComponentModel.type` ディスパッチをタイプセーフに置き換える。
/// レンダラーは `Node: ComponentNode` なカタログ型パラメータを受け取るため、
/// 描画可能なコンポーネントの集合はコンパイル時に確定・網羅される。
/// 一方でコンシューマーが具体的な `Node` を選択・合成できるため拡張にも開かれている。
///
/// `componentNames` は `CatalogNode` が A2UI の 2 種類の障害モードを分離するためのルーティングメタデータ:
/// - このカタログが処理**しない** `component` 名 → 仕様の「unknown component」→ グレースフルフォールバック
/// - 処理**する**が props が不正な名前 → デコード throw → 報告すべきバリデーションエラー
public protocol ComponentNode: Decodable, Sendable, Equatable {
    /// このノードがデコードするワイヤー上の `component` ディスクリミネータの集合。
    /// 各コンポーネントの `componentName` 定数（スキーマ SSOT）から構築され、文字列リテラルは使用しない。
    static var componentNames: Set<String> { get }

    /// インスタンスの id（フラット id-map のキーおよび子参照のターゲット）。
    var id: ComponentId { get }

    /// このインスタンスのワイヤー上の `component` ディスクリミネータ。
    var componentName: String { get }
}

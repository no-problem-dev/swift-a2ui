import Foundation

/// すべての A2UI コンポーネントカタログが準拠するプロトコル。
public protocol ComponentCatalog: Sendable {
    /// このカタログの一意識別子 URI。
    var catalogId: String { get }

    /// カタログの JSON スキーマ文字列を返す。
    static func catalogSchemaJSON() -> String
}

/// swift-a2ui に同梱される基本カタログ。
///
/// A2UI v0.10 仕様に定義された標準の表示・レイアウト・入力コンポーネントを含む。
public struct BasicComponentCatalog: ComponentCatalog, Sendable {
    /// カノニカルなカタログ識別子 URI。
    public static let catalogId = "https://a2ui.org/specification/v0_10/catalogs/basic/catalog.json"

    public var catalogId: String { Self.catalogId }

    public init() {}

    /// カタログスキーマを返す。**Swift コンポーネント型から生成**され、手書き JSON ではない。
    ///
    /// Swift 型（コンポーネントプロパティ宣言 + `SchemaEnumerable` 準拠 enum）が唯一の真実の源。
    /// LLM 向けスキーマはそこから導出されるため、双方がズレることはない。
    /// （`GeneratedSchemaEquivalence` テストが公式 v0.9 カタログとの一致を検証する。）
    public static func catalogSchemaJSON() -> String {
        BasicCatalogSchema.render()
    }
}

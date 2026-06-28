import A2UICore

/// LLM 向けスキーマを Swift で記述するコンポーネント（または関数）のプロトコル。
///
/// 準拠することで Swift 型がスキーマの唯一の真実の源になる。手書きの `catalog.json` は不要。
/// `SchemaRenderer` がすべての準拠型のスキーマを収集してカタログドキュメントを生成する。
public protocol CatalogSchemaDescribing {
    /// この型のタイプセーフなスキーマ。
    static var componentSchema: ComponentSchema { get }
}

/// `String` 型の raw value を持ち、ケースをスキーマ `enum` リストに提供する型のプロトコル。
/// コンポーネントプロパティの enum（例: `TextVariant`）を準拠させることでスキーマにケースを公開する。
public protocol SchemaEnumerable: CaseIterable, RawRepresentable where RawValue == String {}

public extension SchemaEnumerable {
    /// 宣言順のケース raw 文字列。`PropertyType.enumeration` で使用する。
    static var schemaCases: [String] { allCases.map(\.rawValue) }
}

public extension PropertyType {
    /// `SchemaEnumerable` 準拠型から `.enumeration` を構築する。手書きケース文字列は不要。
    static func enumeration<E: SchemaEnumerable>(_ type: E.Type) -> PropertyType {
        .enumeration(E.schemaCases)
    }
}

import A2UICore

/// 1 つのコンポーネントの仕様をタイプセーフに記述する型。LLM 向けスキーマを生成するために使用する。
/// 手書きの `catalog.json` の代わりに Swift 型が唯一の真実の源となる。
///
/// `SchemaRenderer` が `[ComponentSchema]` を公式 A2UI カタログ JSON-Schema ドキュメントに変換する
/// （`catalogs/basic/catalog.json` と意味的に等価）。
public struct ComponentSchema: Sendable, Equatable {
    /// コンポーネント名（`component` ディスクリミネータ const、例: "Text"）。
    public let name: String
    /// 機能カテゴリ（Display / Layout / Input）。設定 UI・ドキュメント・カタログブラウザ向けのメタデータ。
    /// LLM 向けスキーマには出力されない（公式 catalog.json にカテゴリフィールドは存在しない）。
    public let category: ComponentCategory
    /// スキーマに出力される説明文（LLM 向け）。
    public let description: String?
    /// 宣言されたプロパティ（`component`/`id`/`weight` などの共有フィールドは除く）。
    public let properties: [PropertySchema]
    /// このコンポーネントが参加する共有ミックスイン（例: 入力/Button の `.checkable`）。
    public let mixins: [SchemaMixin]

    public init(
        name: String,
        category: ComponentCategory,
        description: String? = nil,
        properties: [PropertySchema],
        mixins: [SchemaMixin] = []
    ) {
        self.name = name
        self.category = category
        self.description = description
        self.properties = properties
        self.mixins = mixins
    }

    /// 必須プロパティ名の一覧。`component` は常に含まれる。
    public var requiredPropertyNames: [String] {
        ["component"] + properties.filter(\.isRequired).map(\.name)
    }
}

/// Basic カタログコンポーネントの機能カテゴリ（公式のコンポーネント構成に準拠）。
/// `CaseIterable` の宣言順がカノニカルな表示順。
public enum ComponentCategory: String, Sendable, Equatable, CaseIterable {
    case display
    case layout
    case input
}

/// 公式カタログで `allOf` を通じて参照される共有スキーマフラグメント。
public enum SchemaMixin: String, Sendable, Equatable, CaseIterable {
    /// `common_types.json#/$defs/Checkable`。バリデーション/無効化用の `checks` 配列を追加する。
    case checkable
}

/// コンポーネントスキーマの 1 プロパティ。
public struct PropertySchema: Sendable, Equatable {
    public let name: String
    public let type: PropertyType
    public let isRequired: Bool
    public let description: String?
    /// スキーマの `default` として出力するオプションのデフォルト値（例: enum のデフォルト "body"）。
    public let defaultValue: StructuredValue?

    public init(
        _ name: String,
        _ type: PropertyType,
        required: Bool = false,
        description: String? = nil,
        default defaultValue: StructuredValue? = nil
    ) {
        self.name = name
        self.type = type
        self.isRequired = required
        self.description = description
        self.defaultValue = defaultValue
    }

    // Ergonomic constructors.
    public static func required(_ name: String, _ type: PropertyType, _ description: String? = nil) -> PropertySchema {
        PropertySchema(name, type, required: true, description: description)
    }

    public static func optional(_ name: String, _ type: PropertyType, _ description: String? = nil, default defaultValue: StructuredValue? = nil) -> PropertySchema {
        PropertySchema(name, type, required: false, description: description, default: defaultValue)
    }
}

/// コンポーネントプロパティの型。common-types の `$ref`、インラインスカラー、列挙型など、
/// A2UI Basic カタログが使用するプロパティの種類を閉じた集合として表現する。
public enum PropertyType: Sendable, Equatable {
    // バインド可能な動的値型 — common_types.json の $ref としてレンダリングされる。
    case dynamicString
    case dynamicNumber
    case dynamicBoolean
    case dynamicStringList
    case dynamicValue
    // 構造的参照。
    case componentId      // common_types.json#/$defs/ComponentId
    case childList        // common_types.json#/$defs/ChildList
    case action           // common_types.json#/$defs/Action
    // インラインスカラー。
    case string
    case number
    case integer
    case boolean
    /// 許可されたケース文字列を持つインライン string enum。
    case enumeration([String])
    /// プロパティ型の配列（例: tabs の オブジェクト配列）。
    indirect case array(PropertyType)
    /// 名前付きサブプロパティを持つインラインオブジェクト（例: タブエントリ { title, child }）。
    case object([PropertySchema])
    /// 上記の閉じた種類に収まらない非定型プロパティ向けの生 JSON-Schema フラグメント
    /// （例: Icon の `oneOf`、DateTimeInput の `allOf`+`if/then`）。
    /// フラグメントはそのまま出力されるため、`description` を含めなければならない
    /// （`renderProperty` は追加しない）。
    case raw(StructuredValue)
}

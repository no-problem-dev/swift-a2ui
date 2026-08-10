import StructuredDataCore
import A2UICore
import AGUICore
import Foundation

/// クライアントの A2UI 対応宣言(`RunAgentInput.context` エントリ)。
///
/// capabilities でもツール metadata でもなく、description 完全一致の context
/// エントリで宣言するのが公式 a2ui-middleware の契約。`value` は
/// `{catalogId}`(または `{catalogId, components}`)を文字列化した JSON。
///
/// **既定は catalogId だけ送る。** A2UI 本体の `supportedCatalogIds` は
/// 文字列 ID の配列で、コンポーネントのスキーマを送るのは
/// `inlineCatalogs`(エージェントが `acceptsInlineCatalogs` を出したときだけ
/// 使える任意の経路)の側。ID が中身を決める鍵なので、中身を変えたら
/// カタログの版を上げる。
public enum A2UISchemaContext {
    /// クライアント側: 宣言エントリを構築する。
    ///
    /// - Parameters:
    ///   - catalogId: クライアントが描画できるカタログの ID。
    ///   - components: カタログのコンポーネントスキーマ(JSON 値)。
    ///     **省略するのが既定**(ID だけ送る)。サーバーがそのカタログを
    ///     知らない場合にだけ、中身を添えて送る用途に使う。
    ///   - marker: この context エントリが宣言であることを示す `description`。
    ///     **既定は公式 middleware の定数**(バイト一致で判別される)。
    ///
    ///     `context` は汎用の配列なので、宣言かどうかはこの文字列でしか
    ///     見分けられない。繋ぎ先が自前で、判別に使う値を決められるなら
    ///     短いものに差し替えてよい — 137 文字を毎 run 送る必要は無い。
    ///     **送る側と読む側で同じ値を使うこと。**
    public static func declaration(
        catalogId: String,
        components: StructuredValue? = nil,
        marker: String = A2UIAGUIConstants.schemaContextDescription
    ) throws -> AGUIContext {
        var object: OrderedObject = ["catalogId": .string(catalogId)]
        if let components {
            object["components"] = components
        }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return AGUIContext(
            description: marker,
            value: String(decoding: try encoder.encode(StructuredValue.object(object)), as: UTF8.self)
        )
    }

    /// サーバー側: context 一覧から A2UI 宣言を探して catalogId を取り出す。
    ///
    /// components の有無は見ない(公式 middleware の `extractFrontendCatalogId` と同じく、
    /// カタログ ID のフォールバック解決はスキーマの有無と独立)。
    public static func declaredCatalogId(
        in context: [AGUIContext],
        marker: String = A2UIAGUIConstants.schemaContextDescription
    ) -> String? {
        guard let entry = declaration(in: context, marker: marker),
              let data = entry.value.data(using: .utf8),
              let value = try? JSONDecoder().decode(StructuredValue.self, from: data) else {
            return nil
        }
        let catalogId = value.objectValue?["catalogId"]?.stringValue
        return (catalogId?.isEmpty ?? true) ? nil : catalogId
    }

    /// サーバー側: A2UI 宣言エントリそのもの(`marker` と完全一致するもの)。
    public static func declaration(
        in context: [AGUIContext],
        marker: String = A2UIAGUIConstants.schemaContextDescription
    ) -> AGUIContext? {
        context.first { $0.description == marker }
    }

    /// 解析済みのカタログ宣言(`{catalogId}` または `{catalogId, components}`)。
    public struct Declaration: Sendable, Equatable {
        /// クライアントが描画できるカタログの ID。
        public let catalogId: String
        /// 宣言された components マップ(コンポーネント名 → JSON Schema)。
        /// **`nil` が既定** — ID だけの宣言。中身はカタログの版が決める。
        public let components: StructuredValue?

        /// 宣言されたコンポーネント名の集合。
        ///
        /// **`nil` は「絞り込みの指定なし」**で、空集合(「1 つも描けない」)とは
        /// 意味が違う。ID だけの宣言では nil になり、受け手は自分が知っている
        /// そのカタログの全体を使う。
        public var componentNames: Set<String>? {
            guard let object = components?.objectValue else {
                return nil
            }
            return Set(object.keys)
        }

        public init(catalogId: String, components: StructuredValue? = nil) {
            self.catalogId = catalogId
            self.components = components
        }
    }

    /// サーバー側: context 内の**全**宣言を出現順で返す。
    ///
    /// クライアントは対応カタログごとに 1 エントリを積み、並び順が優先順位になる
    /// (A2UI 本体の `supportedCatalogIds` ハンドシェイクの AG-UI 運搬形)。
    /// サーバーは自分が知っている catalogId を持つ最初の宣言を選ぶ。
    /// 公式 a2ui-middleware の単一エントリ契約はこの特殊ケース(1 件)。
    ///
    /// **`components` は任意。** 無ければ ID だけの宣言として通す
    /// (中身はカタログの版が決める)。catalogId が空の宣言だけを
    /// 「描画能力なし」として除外する。
    ///
    /// `components` が**空オブジェクト**のときも除外する — 「1 つも描けない」を
    /// 明示した宣言であり、ID だけの宣言(絞り込みの指定なし)とは区別する。
    public static func declarations(
        in context: [AGUIContext],
        marker: String = A2UIAGUIConstants.schemaContextDescription
    ) -> [Declaration] {
        context.compactMap { entry in
            guard entry.description == marker,
                  let data = entry.value.data(using: .utf8),
                  let value = try? JSONDecoder().decode(StructuredValue.self, from: data),
                  let object = value.objectValue,
                  let catalogId = object["catalogId"]?.stringValue,
                  !catalogId.isEmpty else {
                return nil
            }
            guard let components = object["components"] else {
                // ID だけの宣言(既定の形)。
                return Declaration(catalogId: catalogId)
            }
            guard let map = components.objectValue, !map.isEmpty else {
                // 「1 つも描けない」を明示した宣言は落とす。
                return nil
            }
            return Declaration(catalogId: catalogId, components: components)
        }
    }
}

/// エージェント(サーバー側)に注入するレンダリングツールの定義。
///
/// `catalogId` は引数に**含めない** — カタログ選択はホストの権限で、
/// サブエージェントが未登録カタログを発明できないようにする(公式設計)。
public enum A2UIRenderTool {
    public static func definition() -> AGUITool {
        AGUITool(
            name: A2UIAGUIConstants.renderToolName,
            description: "Render a dynamic A2UI \(A2UIVersion.current) surface with structured parameters. "
                + "Follow the A2UI render tool usage guide provided in context.",
            parameters: .object([
                "type": .string("object"),
                "properties": .object([
                    "surfaceId": .object([
                        "type": .string("string"),
                        "description": .string("Unique surface identifier."),
                    ]),
                    "components": .object([
                        "type": .string("array"),
                        "items": .object(["type": .string("object")]),
                        "description": .string(
                            "A2UI \(A2UIVersion.current) component array (flat format). The root component must have id \"root\"."
                        ),
                    ]),
                    "data": .object([
                        "type": .string("object"),
                        "description": .string("Initial data model for the surface. Written to the root path."),
                    ]),
                ]),
                "required": .array([.string("surfaceId"), .string("components")]),
            ])
        )
    }
}

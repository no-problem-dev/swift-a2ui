import A2UICore
import AGUICore
import Foundation

/// クライアントの A2UI 対応宣言(`RunAgentInput.context` エントリ)。
///
/// capabilities でもツール metadata でもなく、description 完全一致の context
/// エントリで宣言するのが公式 a2ui-middleware の契約。`value` は
/// `{catalogId, components}` を文字列化した JSON。
public enum A2UISchemaContext {
    /// クライアント側: 宣言エントリを構築する。
    ///
    /// - Parameters:
    ///   - catalogId: クライアントが描画できるカタログの ID。
    ///   - components: カタログのコンポーネントスキーマ(JSON 値)。
    public static func declaration(
        catalogId: String,
        components: StructuredValue
    ) throws -> AGUIContext {
        let value: StructuredValue = .object([
            "catalogId": .string(catalogId),
            "components": components,
        ])
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return AGUIContext(
            description: A2UIAGUIConstants.schemaContextDescription,
            value: String(decoding: try encoder.encode(value), as: UTF8.self)
        )
    }

    /// サーバー側: context 一覧から A2UI 宣言を探して catalogId を取り出す。
    ///
    /// components の有無は見ない(公式 middleware の `extractFrontendCatalogId` と同じく、
    /// カタログ ID のフォールバック解決はスキーマの有無と独立)。
    public static func declaredCatalogId(in context: [AGUIContext]) -> String? {
        guard let entry = declaration(in: context),
              let data = entry.value.data(using: .utf8),
              let value = try? JSONDecoder().decode(StructuredValue.self, from: data) else {
            return nil
        }
        let catalogId = value.objectValue?["catalogId"]?.stringValue
        return (catalogId?.isEmpty ?? true) ? nil : catalogId
    }

    /// サーバー側: A2UI 宣言エントリそのもの(description 完全一致)。
    public static func declaration(in context: [AGUIContext]) -> AGUIContext? {
        context.first { $0.description == A2UIAGUIConstants.schemaContextDescription }
    }

    /// 解析済みのカタログ宣言(`{catalogId, components}`)。
    public struct Declaration: Sendable, Equatable {
        /// クライアントが描画できるカタログの ID。
        public let catalogId: String
        /// 宣言された components マップ(コンポーネント名 → JSON Schema)。
        public let components: StructuredValue

        /// 宣言されたコンポーネント名の集合。
        public var componentNames: Set<String> {
            guard let object = components.objectValue else {
                return []
            }
            return Set(object.keys)
        }

        public init(catalogId: String, components: StructuredValue) {
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
    /// catalogId が空・components が空オブジェクトの宣言は「描画能力なし」として
    /// 除外する(公式 middleware の empty-schema 判定と同じ)。
    public static func declarations(in context: [AGUIContext]) -> [Declaration] {
        context.compactMap { entry in
            guard entry.description == A2UIAGUIConstants.schemaContextDescription,
                  let data = entry.value.data(using: .utf8),
                  let value = try? JSONDecoder().decode(StructuredValue.self, from: data),
                  let object = value.objectValue,
                  let catalogId = object["catalogId"]?.stringValue,
                  !catalogId.isEmpty,
                  let components = object["components"],
                  !(components.objectValue?.isEmpty ?? true) else {
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

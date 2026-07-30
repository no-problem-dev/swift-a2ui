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

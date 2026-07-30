import A2UICore
import Foundation
import LLMClient
import LLMTool
import StructuredDataCore

/// 副エージェントに強制する内側ツール — `render_a2ui`。
///
/// ミラー元: `@ag-ui/a2ui-toolkit` の `RENDER_A2UI_TOOL_DEF`。
///
/// 副エージェントにはこのツールを**1 つだけ**バインドし `toolChoice: .tool(name)` で
/// 名指し強制する。テキストで返す選択肢がプロバイダ API のレベルで消えるため、
/// 「A2UI JSON をテキスト本文に書いてしまう」失敗モードが原理的に起きない。
///
/// `catalogId` は引数に**含めない** — カタログはホストの所有物であり、副エージェントが
/// 登録されていないカタログを名乗れないようにする（公式と同じ設計）。
///
/// `components` の要素スキーマは意図的に空（`type: object`）にする。カタログは実行時に
/// 決まり、巨大な `oneOf` union はプロバイダのスキーマ制約に触れやすく、構造検証は
/// `A2UIValidation` 側で行うため。カタログ定義は副エージェントの**プロンプト本文**に
/// 埋め込む（`A2UISubagentPrompt`）。
public struct RenderA2UITool: Tool {
    /// ツール名。既定は公式と同じ `render_a2ui`。
    public let toolName: String

    public init(toolName: String = A2UISubagentConstants.renderToolName) {
        self.toolName = toolName
    }

    public var toolDescription: String {
        "Render a dynamic A2UI surface. The root component must have id 'root'. "
            + "Use components from the available catalog only."
    }

    public var inputSchema: JSONSchema {
        .object(
            properties: [
                "surfaceId": .string(description: "Unique surface identifier."),
                "components": .array(
                    description: "A2UI component array (flat format). The root component must have id 'root'.",
                    items: .object(properties: [:], additionalProperties: true)
                ),
                "data": .object(
                    description: "Optional initial data model for the surface (form values, list items, etc.).",
                    properties: [:],
                    additionalProperties: true
                ),
            ],
            required: ["surfaceId", "components"]
        )
    }

    /// 副エージェントの呼び出しでは実行されない — 呼び出し側（`A2UISubagentRunner`）が
    /// ツール呼び出しの引数を直接読み取るため。ツールセットに登録するための形だけを満たす。
    public func execute(with argumentsData: Data) async throws -> ToolResult {
        .text("{}")
    }
}

/// 副エージェントが返した `render_a2ui` の引数。
public struct RenderA2UIArguments: Sendable, Equatable {
    public let surfaceId: String
    public let components: [StructuredValue]
    public let data: StructuredValue?

    public init(surfaceId: String, components: [StructuredValue], data: StructuredValue?) {
        self.surfaceId = surfaceId
        self.components = components
        self.data = data
    }

    /// ツール呼び出しの生引数（JSON）から取り出す。
    ///
    /// モデル出力は untrusted なので型を narrow する（数値・オブジェクト・null が来ても
    /// 落ちないようにし、空文字の surfaceId はフォールバックに委ねるため空として扱う）。
    public init?(argumentsData: Data) {
        guard let root = try? JSONParser().parse(argumentsData) else { return nil }
        let surfaceId = root["surfaceId"].stringValue ?? ""
        guard let components = root["components"].arrayValue else { return nil }
        // data はオブジェクトのみ受理する（配列・null・スカラーはデータモデルとして無効）
        let rawData = root["data"]
        let data: StructuredValue? = if case .object = rawData { rawData } else { nil }
        self.init(surfaceId: surfaceId, components: components, data: data)
    }
}

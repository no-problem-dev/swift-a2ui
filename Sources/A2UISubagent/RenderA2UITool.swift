import JSONParsing
import A2UICore
import A2UIParser
import Foundation
import LLMClient
import LLMTool
import StructuredDataCore

/// 副エージェントに強制する内側ツール — `render_a2ui`。
///
/// ミラー元: `@ag-ui/a2ui-toolkit` の `RENDER_A2UI_TOOL_DEF`（typed）と
/// `ag_ui_adk.a2ui_tool` の Gemini 向け宣言（freeform）。
///
/// 副エージェントにはこのツールを**1 つだけ**バインドし `toolChoice: .tool(name)` で
/// 名指し強制する。テキストで返す選択肢がプロバイダ API のレベルで消えるため、
/// 「A2UI JSON をテキスト本文に書いてしまう」失敗モードが原理的に起きない。
///
/// `catalogId` は引数に**含めない** — カタログはホストの所有物であり、副エージェントが
/// 登録されていないカタログを名乗れないようにする（公式と同じ設計）。
///
/// カタログ定義はツール引数の JSON Schema には入れず、副エージェントの**プロンプト本文**
/// （`## Available Components`）に埋め込む。構造検証は `A2UIValidation` 側で行う。
public struct RenderA2UITool: Tool {
    /// 引数の宣言形。プロバイダの関数呼び出しの厳格さに応じて選ぶ。
    public enum PayloadShape: Sendable, Equatable {
        /// `components: array<object>` / `data: object` として宣言する（公式共有定義）。
        /// LangGraph / OpenAI 系はスキーマが緩くてもプロンプトの記述から埋められる。
        case typed
        /// `components` / `data` を **JSON 文字列**として宣言する（ADK/Gemini 向けの glue）。
        ///
        /// Gemini の function-calling は typed な引数を**厳格に**埋めるため、プロパティを
        /// 持たない `array<object>` には空の `{}` を返し、宣言していないフィールドは
        /// 一切出力しない（実測: `Key 'component' not found` → 骨組み宣言後は
        /// `Key 'children'/'text' not found`）。文字列で受ければモデルはプロンプトの
        /// カタログ定義に従って A2UI JSON を自由記述でき、こちらでパースし直せる。
        case freeform
    }

    /// ツール名。既定は公式と同じ `render_a2ui`。
    public let toolName: String
    /// 引数の宣言形。
    public let payloadShape: PayloadShape

    public init(
        toolName: String = A2UISubagentConstants.renderToolName,
        payloadShape: PayloadShape = .typed
    ) {
        self.toolName = toolName
        self.payloadShape = payloadShape
    }

    public var toolDescription: String {
        "Render a dynamic A2UI surface. The root component must have id 'root'. "
            + "Use components from the available catalog only."
    }

    public var inputSchema: JSONSchema {
        switch payloadShape {
        case .typed:
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
        case .freeform:
            .object(
                properties: [
                    "surfaceId": .string(description: "Unique surface identifier."),
                    "components": .string(
                        description: "The A2UI component array as a JSON string, e.g."
                            + #" '[{"id":"root","component":"Text","text":"Hi"}]'."#
                            + " The root component must have id 'root'."
                    ),
                    "data": .string(
                        description: "Optional surface data model as a JSON string, e.g."
                            + #" '{"items":[...]}'. Use '{}' when there is none."#
                    ),
                ],
                required: ["surfaceId", "components"]
            )
        }
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
    /// `components` / `data` は**構造化されていても JSON 文字列でも**受け取る
    /// （`.typed` / `.freeform` の両方の宣言形に対応する）。文字列の場合は
    /// `JSONSanitizer` 経由で修復してからパースする — Gemini の自由記述 JSON は
    /// スマートクォート・コードフェンス・末尾カンマを含むことが多い。
    ///
    /// パースできなかった場合は空として扱い、検証器に弾かせてリトライループに回す
    /// （壊れたペイロードをコミットしない）。
    public init?(argumentsData: Data) {
        guard let root = try? JSONParser().parse(argumentsData) else { return nil }
        let surfaceId = root["surfaceId"].stringValue ?? ""

        guard let components = Self.array(from: root["components"]) else { return nil }
        self.init(
            surfaceId: surfaceId,
            components: components,
            data: Self.object(from: root["data"])
        )
    }

    /// 配列、または配列を表す JSON 文字列を配列として取り出す。
    private static func array(from value: StructuredValue) -> [StructuredValue]? {
        if let array = value.arrayValue {
            return array
        }
        guard let json = value.stringValue else { return nil }
        let sanitized = JSONSanitizer.sanitize(json)
        guard !sanitized.isEmpty, let parsed = try? JSONParser().parse(Data(sanitized.utf8)) else {
            return nil
        }
        if let array = parsed.arrayValue {
            return array
        }
        // 単一オブジェクトは配列にラップする（公式 parse_and_fix と同じ寛容さ）
        if case .object = parsed {
            return [parsed]
        }
        return nil
    }

    /// オブジェクト、またはオブジェクトを表す JSON 文字列をオブジェクトとして取り出す。
    /// データモデルとして無効なもの（配列・null・スカラー・空 `{}`）は `nil`。
    private static func object(from value: StructuredValue) -> StructuredValue? {
        if case .object(let fields) = value {
            return fields.isEmpty ? nil : value
        }
        guard let json = value.stringValue else { return nil }
        let sanitized = JSONSanitizer.sanitize(json)
        guard !sanitized.isEmpty,
              let parsed = try? JSONParser().parse(Data(sanitized.utf8)),
              case .object(let fields) = parsed,
              !fields.isEmpty else {
            return nil
        }
        return parsed
    }
}

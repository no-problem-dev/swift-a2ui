import Foundation
import A2UICore
import A2UIParser
import A2UIPrompt
import A2UITyped
import LLMClient
import LLMTool

/// 公式 A2UI ツール呼び出しパターン — Python SDK の `_SendA2uiJsonToClientTool`
/// （`a2ui.adk.send_a2ui_to_client_toolset`）の Swift 対応。
///
/// LLM が A2UI JSON を作成し `a2ui_json` 引数として渡す。このツールは（自動修正付きで）パースし、
/// `Catalog` に対して検証を行い、検証済みペイロードを `validated_a2ui_json` キーでホストに届ける。
/// 失敗はツールエラーとして返し、モデルが同一ループ内で自己修正できる。`TurnEndingTool` として、
/// 成功した呼び出しはターンを追加推論なしで終了させる（ADK `skip_summarization`）。
public struct SendA2UIToClientTool<Catalog: A2UICatalog>: TurnEndingTool {

    private let examples: String?
    private let promptBuilder: A2UIPromptBuilder

    public init(examples: String? = nil, promptBuilder: A2UIPromptBuilder = A2UIPromptBuilder()) {
        self.examples = examples
        self.promptBuilder = promptBuilder
    }

    public var toolName: String { A2UIToolConstants.toolName }

    /// スキーマブロックと手本をツール自身が system prompt に同伴させる
    /// （公式 `_SendA2uiJsonToClientTool.process_llm_request` 相当）。
    public var systemInstruction: String? {
        var sections = [promptBuilder.schemaBlock()]
        if let examples, !examples.isEmpty {
            sections.append("### Examples:\n\(examples)")
        }
        return sections.joined(separator: "\n\n")
    }

    public var toolDescription: String {
        "Sends A2UI JSON to the client to render rich UI for the user. This tool"
            + " can be called multiple times in the same call to render multiple UI"
            + " surfaces. Args: \(A2UIToolConstants.jsonArgName): Valid A2UI JSON Schema to"
            + " send to the client. The A2UI JSON Schema definition is between"
            + " \(SchemaBlockFormatter.beginMarker) and"
            + " \(SchemaBlockFormatter.endMarker) in the system instructions."
    }

    public var inputSchema: JSONSchema {
        .object(
            properties: [
                A2UIToolConstants.jsonArgName: .string(description: "valid A2UI JSON Schema to send to the client."),
            ],
            required: [A2UIToolConstants.jsonArgName]
        )
    }

    public func execute(with argumentsData: Data) async throws -> ToolResult {
        func failure(_ message: String) -> ToolResult {
            .error("Failed to call A2UI tool \(A2UIToolConstants.toolName): \(message)")
        }

        guard let a2uiJSON = Self.normalizedA2UIJSON(from: argumentsData),
              !a2uiJSON.isEmpty else {
            return failure("Failed to call tool \(A2UIToolConstants.toolName) because missing required arg \(A2UIToolConstants.jsonArgName)")
        }

        let messages: [ServerMessage]
        do {
            messages = try A2UIPayloadFixer.parseAndFix(a2uiJSON)
        } catch {
            return failure("\(error)")
        }

        // Validate with the SAME allowlists the promptBuilder pruned the schema by: a component or
        // message the model was never offered must fail here (and self-correct in-loop), not slip
        // through to the renderer.
        let issues = A2UIValidation.issues(
            in: messages,
            for: Catalog.self,
            allowedComponents: promptBuilder.allowedComponents,
            allowedMessages: promptBuilder.allowedMessages
        )
        guard issues.isEmpty else {
            return failure(issues.joined(separator: "; "))
        }

        return .json(try JSONEncoder().encode(ValidatedPayload(validated_a2ui_json: messages)))
    }

    /// `a2ui_json` 引数を正規化された JSON 文字列として取り出す。
    ///
    /// 公式契約（Python SDK 準拠）では `a2ui_json` は「A2UI JSON 配列を文字列化したもの」だが、
    /// 一部のモデル（例: gemini flash-lite 系）は文字列化せず生の JSON 配列／オブジェクトを
    /// そのまま引数に積む。その場合 `String?` への decode は失敗し「引数欠落」と誤認されるため、
    /// 生 JSON を再シリアライズして後段パーサが期待する文字列形に揃える。
    static func normalizedA2UIJSON(from data: Data) -> String? {
        // Fast path: 公式契約どおり文字列で渡されたケース。
        if let s = (try? JSONDecoder().decode(ToolArgs.self, from: data))?.a2ui_json {
            return s
        }
        // Tolerant path: 生 JSON（配列／オブジェクト）で渡されたケースを再文字列化する。
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let raw = root[A2UIToolConstants.jsonArgName] else {
            return nil
        }
        if let s = raw as? String { return s }
        guard JSONSerialization.isValidJSONObject(raw),
              let reencoded = try? JSONSerialization.data(withJSONObject: raw),
              let s = String(data: reencoded, encoding: .utf8) else {
            return nil
        }
        return s
    }
}

private struct ToolArgs: Decodable { let a2ui_json: String? }
private struct ValidatedPayload: Encodable { let validated_a2ui_json: [ServerMessage] }

import Foundation
import A2UICore
import A2UIParser
import A2UIPrompt
import A2UITyped
import LLMClient
import LLMTool

/// The official A2UI tool-call generation pattern — the Swift counterpart of the Python SDK's
/// `_SendA2uiJsonToClientTool` (`a2ui.adk.send_a2ui_to_client_toolset`).
///
/// The LLM authors the A2UI JSON itself and passes it as the `a2ui_json` argument; this tool
/// parses (with autofixes), validates against `Catalog`, and returns the validated payload under
/// the `validated_a2ui_json` key for the host to deliver to the client. Failures are returned as
/// tool errors so the model can self-correct within the same loop. As a `TurnEndingTool`, a
/// successful call ends the turn without a further inference (ADK `skip_summarization`).
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

        guard let a2uiJSON = (try? JSONDecoder().decode(ToolArgs.self, from: argumentsData))?.a2ui_json,
              !a2uiJSON.isEmpty else {
            return failure("Failed to call tool \(A2UIToolConstants.toolName) because missing required arg \(A2UIToolConstants.jsonArgName)")
        }

        let messages: [ServerMessage]
        do {
            messages = try A2UIPayloadFixer.parseAndFix(a2uiJSON)
        } catch {
            return failure("\(error)")
        }

        let issues = A2UIValidation.issues(in: messages, for: Catalog.self)
        guard issues.isEmpty else {
            return failure(issues.joined(separator: "; "))
        }

        return .json(try JSONEncoder().encode(ValidatedPayload(validated_a2ui_json: messages)))
    }
}

private struct ToolArgs: Decodable { let a2ui_json: String? }
private struct ValidatedPayload: Encodable { let validated_a2ui_json: [ServerMessage] }

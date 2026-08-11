import Foundation
import A2UICore
import A2UIParser
import A2UIPrompt
import A2UITyped
import LLMClient
import LLMTool

/// The A2UI tool-call pattern — the Swift counterpart of the Python SDK's
/// `_SendA2uiJsonToClientTool` (`a2ui.adk.send_a2ui_to_client_toolset`).
///
/// The LLM composes A2UI JSON and passes it as the `a2ui_json` argument. This tool parses it
/// (repairing common malformations on the way) and validates it against `Catalog` and the same
/// allowlists the prompt was pruned by. A successful call returns a JSON result carrying the
/// validated messages under the `validated_a2ui_json` key, which is what the host delivers to the
/// client. Anything that fails to parse or validate comes back as a tool error carrying the
/// reason instead, so the model self-corrects inside the same loop and nothing unvalidated
/// reaches the renderer. Being a `TurnEndingTool`, a successful call ends the turn with no
/// further inference (ADK `skip_summarization`).
public struct SendA2UIToClientTool<Catalog: A2UICatalog>: TurnEndingTool {

    private let examples: String?
    private let promptBuilder: A2UIPromptBuilder

    public init(examples: String? = nil, promptBuilder: A2UIPromptBuilder = A2UIPromptBuilder()) {
        self.examples = examples
        self.promptBuilder = promptBuilder
    }

    public var toolName: String { A2UIToolConstants.toolName }

    /// The schema block and the worked examples that the tool itself carries into the system
    /// prompt when it is attached (the counterpart of the upstream
    /// `_SendA2uiJsonToClientTool.process_llm_request`).
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

        let messages: [AgentMessage]
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

    /// Pulls the `a2ui_json` argument out as a normalized JSON string.
    ///
    /// The contract (as in the Python SDK) is that `a2ui_json` is a *stringified* A2UI JSON array,
    /// but some models — gemini flash-lite among them — put the raw JSON array or object in the
    /// argument instead. Decoding that as `String?` fails and would be misreported to the model as
    /// a missing argument, so raw JSON is re-serialized into the string form the downstream parser
    /// expects.
    static func normalizedA2UIJSON(from data: Data) -> String? {
        // Fast path: passed as a string, per the contract.
        if let s = (try? JSONDecoder().decode(ToolArgs.self, from: data))?.a2ui_json {
            return s
        }
        // Tolerant path: re-stringify a raw JSON array or object.
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
private struct ValidatedPayload: Encodable { let validated_a2ui_json: [AgentMessage] }

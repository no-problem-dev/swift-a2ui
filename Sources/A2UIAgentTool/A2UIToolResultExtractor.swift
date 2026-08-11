import Foundation
import A2UICore

/// Extracts the client-bound A2UI messages from a tool result — the Swift counterpart of the
/// Python SDK's `A2uiPartConverter` tool-response path.
///
/// Only a successful `send_a2ui_json_to_client` result carries UI. An error result is dropped
/// rather than shown to the client — the model apologizes for it under the workflow rules — and
/// results from other tools are ignored.
public enum A2UIToolResultExtractor {

    /// Returns what a tool result carried, naming the reason whenever that is not UI.
    ///
    /// A single "no messages" answer would leave the caller unable to tell a result from another
    /// tool — which is normal and uninteresting — from a `send_a2ui_json_to_client` result whose
    /// envelope would not decode, which means the client is about to show nothing and no one knows.
    public static func payload(fromToolResult name: String, output: String, isError: Bool) -> A2UIToolPayload {
        guard name == A2UIToolConstants.toolName else { return .otherTool }
        guard !isError else { return .toolError }
        guard let decoded = try? JSONDecoder().decode(ValidatedPayload.self, from: Data(output.utf8)) else {
            return .unreadable
        }
        return .messages(decoded.messages)
    }

    /// Mirrors what `SendA2UIToClientTool` writes, keyed by the shared wire constant.
    private struct ValidatedPayload: Decodable {
        let messages: [AgentMessage]

        private struct Key: CodingKey {
            let stringValue: String
            var intValue: Int? { nil }
            init?(stringValue: String) { self.stringValue = stringValue }
            init?(intValue: Int) { nil }
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: Key.self)
            messages = try container.decode(
                [AgentMessage].self,
                forKey: Key(stringValue: A2UIToolConstants.validatedJSONKey)!
            )
        }
    }
}

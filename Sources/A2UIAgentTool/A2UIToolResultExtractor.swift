import Foundation
import A2UICore

/// Extracts the client-bound A2UI messages from a tool result — the Swift counterpart of the
/// Python SDK's `A2uiPartConverter` tool-response path.
///
/// Only a successful `send_a2ui_json_to_client` result carries UI. An error result is dropped
/// rather than shown to the client — the model apologizes for it under the workflow rules — and
/// results from other tools are ignored.
public enum A2UIToolResultExtractor {

    /// Returns the A2UI agent messages carried by a tool result, or `nil` when the result is not
    /// a successful `send_a2ui_json_to_client` call or its payload does not decode.
    public static func messages(fromToolResult name: String, output: String, isError: Bool) -> [AgentMessage]? {
        guard name == A2UIToolConstants.toolName, !isError else { return nil }
        struct Payload: Decodable { let validated_a2ui_json: [AgentMessage] }
        guard let payload = try? JSONDecoder().decode(Payload.self, from: Data(output.utf8)) else { return nil }
        return payload.validated_a2ui_json
    }
}

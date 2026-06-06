import Foundation
import A2UICore

/// Extracts client-bound A2UI messages from a tool result — the Swift counterpart of the Python
/// SDK's `A2uiPartConverter` tool-response path.
///
/// Only successful results of `send_a2ui_json_to_client` carry UI. Error results are dropped
/// (never shown to the client — the model apologizes per the workflow rules), and results of
/// other tools are ignored.
public enum A2UIToolResultExtractor {

    public static func messages(fromToolResult name: String, output: String, isError: Bool) -> [ServerMessage]? {
        guard name == A2UIToolConstants.toolName, !isError else { return nil }
        struct Payload: Decodable { let validated_a2ui_json: [ServerMessage] }
        guard let payload = try? JSONDecoder().decode(Payload.self, from: Data(output.utf8)) else { return nil }
        return payload.validated_a2ui_json
    }
}

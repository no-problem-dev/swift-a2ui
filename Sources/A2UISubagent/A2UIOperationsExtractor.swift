import A2UICore
import Foundation

/// Pulls A2UI operations out of a tool result in the two-stage setup.
///
/// Only a successful `generate_a2ui` result carries UI. Error results are dropped instead of
/// being shown to the client — the model sees them and corrects itself inside the same loop.
public enum A2UIOperationsExtractor {

    /// Returns what a tool result carried, naming the reason whenever that is not UI.
    ///
    /// The three ways a result carries no operations call for opposite responses: a result from
    /// another tool is ordinary and uninteresting, a tool error is already being handled by the
    /// model inside the loop, and an envelope that will not decode means `generate_a2ui` reported
    /// success while the surface it promised is unreadable. One empty answer for all three left the
    /// caller no way to notice the last one.
    ///
    /// - Parameters:
    ///   - name: Name of the tool that produced this result.
    ///   - output: The result text; `{"a2ui_operations": [...]}` is expected.
    ///   - isError: Whether the tool reported an error.
    ///   - toolName: Name to match against. Override it when the host renamed the outer tool
    ///     away from `generate_a2ui`.
    public static func payload(
        fromToolResult name: String,
        output: String,
        isError: Bool,
        toolName: String = A2UISubagentConstants.generateToolName
    ) -> A2UIToolPayload {
        guard name == toolName else { return .otherTool }
        guard !isError else { return .toolError }
        guard let envelope = try? JSONDecoder().decode(OperationsEnvelope.self, from: Data(output.utf8)) else {
            return .unreadable
        }
        return .messages(envelope.messages)
    }
}

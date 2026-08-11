import A2UICore
import Foundation

/// Pulls A2UI operations out of a tool result in the two-stage setup.
///
/// Only a successful `generate_a2ui` result carries UI. Error results are dropped instead of
/// being shown to the client — the model sees them and corrects itself inside the same loop.
public enum A2UIOperationsExtractor {

    /// Returns the A2UI messages a tool result carries, or `nil` when it carries none.
    ///
    /// `nil` covers three cases a caller cannot tell apart: the result came from a different
    /// tool, the tool errored, or the envelope failed to decode. Treat it as "no UI here"
    /// rather than as a decode failure worth reporting.
    ///
    /// - Parameters:
    ///   - name: Name of the tool that produced this result.
    ///   - output: The result text; `{"a2ui_operations": [...]}` is expected.
    ///   - isError: Whether the tool reported an error. An error result always yields `nil`.
    ///   - toolName: Name to match against. Override it when the host renamed the outer tool
    ///     away from `generate_a2ui`.
    public static func messages(
        fromToolResult name: String,
        output: String,
        isError: Bool,
        toolName: String = A2UISubagentConstants.generateToolName
    ) -> [AgentMessage]? {
        guard name == toolName, !isError else { return nil }
        struct Envelope: Decodable { let a2ui_operations: [AgentMessage] }
        guard let envelope = try? JSONDecoder().decode(Envelope.self, from: Data(output.utf8)) else {
            return nil
        }
        return envelope.a2ui_operations
    }
}

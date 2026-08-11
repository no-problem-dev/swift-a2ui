/// Wire constants for carrying A2UI over AG-UI.
///
/// Mirrors `middlewares/a2ui-middleware` in the upstream ag-ui repository (`src/index.ts` /
/// `src/tools.ts`). These strings are a wire contract matched byte for byte, not prose.
public enum A2UIAGUIConstants {
    /// Discriminator value of `ACTIVITY_SNAPSHOT.activityType`.
    public static let activityType = "a2ui-surface"

    /// Content key of a paint snapshot. The value is an array of A2UI envelopes
    /// (`{version, <one op>}`).
    public static let operationsKey = "a2ui_operations"

    /// `description` of the `RunAgentInput.context` entry with which a client declares A2UI
    /// support. The middleware discriminates on an **exact** match (the `—` is U+2014).
    public static let schemaContextDescription =
        "A2UI Component Schema — available components for generating UI surfaces. "
            + "Use these component names and properties when creating A2UI operations."

    /// Name of the rendering tool injected into the agent (server side).
    public static let renderToolName = "render_a2ui"

    /// Name of the outer tool offered to the planner.
    public static let generateToolName = "generate_a2ui"

    /// Name of the synthetic tool that pins a user action into the conversation history.
    /// It is never declared to the agent as a callable tool.
    public static let logActionToolName = "log_a2ui_event"

    /// messageId for a single surface: one message per tool call carries the whole lifecycle
    /// (building → retrying → paint).
    public static func surfaceMessageId(toolCallId: String) -> String {
        "a2ui-surface-\(toolCallId)"
    }

    /// messageId to use when one tool call paints several surfaces — one snapshot per surfaceId.
    public static func surfaceMessageId(surfaceId: String, toolCallId: String) -> String {
        "a2ui-surface-\(surfaceId)-\(toolCallId)"
    }
}

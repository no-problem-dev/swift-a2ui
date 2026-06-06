/// Constants for the official A2UI tool-call generation pattern — the Swift counterpart of the
/// Python SDK's `a2ui.schema.constants` tool block (`A2UI_TOOL_NAME` etc.).
public enum A2UIToolConstants {
    /// The function name the LLM calls to send UI to the client.
    public static let toolName = "send_a2ui_json_to_client"
    /// Result key carrying the validated payload on success.
    public static let validatedJSONKey = "validated_a2ui_json"
    /// Result key carrying the failure description (returned to the model, never to the client).
    public static let errorKey = "error"
    /// The tool's single required string argument.
    public static let jsonArgName = "a2ui_json"
}

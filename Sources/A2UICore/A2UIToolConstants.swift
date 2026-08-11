/// The names an LLM tool call uses to hand a UI to the client: the tool itself and the keys its
/// result carries.
///
/// They mirror the `a2ui.schema.constants` tool block of the Python SDK (`A2UI_TOOL_NAME` and
/// friends), so a Swift host and a Python host present the same tool to a model. Change one here
/// and prompts written against the other stop matching.
public enum A2UIToolConstants {
    /// Function the model calls to send a UI to the client.
    public static let toolName = "send_a2ui_json_to_client"
    /// Result key holding the payload once it has passed validation.
    public static let validatedJSONKey = "validated_a2ui_json"
    /// Result key holding the failure. It goes back to the model to retry with, and is never
    /// forwarded to the client.
    public static let errorKey = "error"
    /// The tool's only required argument: a string carrying the A2UI JSON.
    public static let jsonArgName = "a2ui_json"
}

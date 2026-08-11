/// The names an LLM tool call uses to hand a UI to the client: the tool itself and the keys its
/// result carries.
///
/// They mirror the `a2ui.schema.constants` tool block of the Python SDK (`A2UI_TOOL_NAME` and
/// friends), so a Swift host and a Python host present the same tool to a model. Every one of them
/// is what actually decides the wire: `validatedJSONKey` is used as an explicit coding key rather
/// than duplicated as a Swift property name, so changing it here changes the result the tool
/// writes. A constant that only looks authoritative is worse than none.
public enum A2UIToolConstants {
    /// Function the model calls to send a UI to the client.
    public static let toolName = "send_a2ui_json_to_client"
    /// Result key holding the payload once it has passed validation.
    public static let validatedJSONKey = "validated_a2ui_json"
    /// The tool's only required argument: a string carrying the A2UI JSON.
    public static let jsonArgName = "a2ui_json"
}

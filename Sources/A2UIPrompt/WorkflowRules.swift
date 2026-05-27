/// Default workflow rules injected into every A2UI system prompt.
///
/// These rules instruct the LLM how to produce valid A2UI responses:
/// which XML-like tags to wrap JSON in, ordering constraints for the
/// `components` array, and so on. The text matches the Python SDK's
/// `DEFAULT_WORKFLOW_RULES` constant verbatim.
public enum A2UIWorkflowRules {
    /// The default set of rules, matching the Python SDK's
    /// `DEFAULT_WORKFLOW_RULES` string exactly.
    public static let `default` = """
    The generated response MUST follow these rules:
    - The response can contain one or more A2UI JSON blocks.
    - Each A2UI JSON block MUST be wrapped in `<a2ui-json>` and `</a2ui-json>` tags.
    - Between or around these blocks, you can provide conversational text.
    - The JSON part MUST be a single, raw JSON object (usually a list of A2UI messages) and MUST validate against the provided A2UI JSON SCHEMA.
    - Top-Down Component Ordering: Within the `components` list of a message:
        - The 'root' component MUST be the FIRST element.
        - Parent components MUST appear before their child components.
        This specific ordering allows the streaming parser to yield and render the UI incrementally as it arrives.
    """
}

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

    /// Workflow rules for the **tool-call** generation pattern (the official
    /// `send_a2ui_json_to_client` tool, mirroring the Python SDK's `SendA2uiToClientToolset`).
    ///
    /// Replaces the tag-wrapping clauses of `default` with tool-call clauses; ordering and
    /// validation constraints are unchanged. The validation/apology clauses match the official
    /// rizzcharts sample's workflow instructions.
    public static let toolCall = """
    The generated response MUST follow these rules:
    - You MUST send UI to the client by calling the `send_a2ui_json_to_client` tool with the `a2ui_json` argument set to the A2UI JSON payload.
    - The `a2ui_json` argument MUST be a single, raw JSON array of A2UI messages and MUST validate against the provided A2UI JSON SCHEMA.
    - The tool can be called multiple times in the same turn to render multiple UI surfaces.
    - Around tool calls, you can provide conversational text.
    - Top-Down Component Ordering: Within the `components` list of a message:
        - The 'root' component MUST be the FIRST element.
        - Parent components MUST appear before their child components.
    - The payload will be validated against the A2UI JSON SCHEMA and rejected if it does not conform.
    - If you get an error in the tool response apologize to the user and let them know they should try again.
    """

    /// Path-resolution scope rules (spec §"Path resolution & scope", v0.10). The JSON schemas can
    /// express the template `ChildList` *shape* but not the scope *semantics*, so models invent
    /// absolute paths inside templates (resolving to undefined → empty UI). This prose ports the
    /// normative spec wording for the prompt.
    public static let scopeRules = """
    Data binding scope rules:
    - Paths starting with '/' are ABSOLUTE: they always resolve from the root of the data model, even inside a template.
    - When a container's `children` uses a template ({"componentId": ..., "path": "/items"}), the client instantiates the template once per array element, and inside it any path WITHOUT a leading '/' is RELATIVE to that element (e.g. `name` resolves to /items/0/name, /items/1/name, ...).
    - Therefore, inside template components you MUST bind item fields with relative paths (no leading slash). Use absolute paths there only to reference root-level values.
    - To bind the array element itself (e.g. iterating an array of strings), use {"path": "."}.
    """

    /// Required-property reminders for the **basic catalog** components.
    ///
    /// These mirror the natural-language hints the Google Python SDK includes alongside the basic
    /// catalog: although the required properties are already encoded in the schema's `required`
    /// arrays, LLMs follow an explicit prose reminder more reliably. This is basic-catalog domain
    /// knowledge, so it lives here in the library rather than in each consuming app.
    public static let basicCatalogRules = """
    Instructions specific to the basic catalog:
    **REQUIRED PROPERTIES:** You MUST include ALL required properties for every component, even if they are inside a template or will be bound to data.
    - For 'Text', you MUST provide 'text'. If dynamic, use { "path": "..." }.
    - For 'Image', you MUST provide 'url'. If dynamic, use { "path": "..." }.
    - For 'Button', you MUST provide 'action'.
    - For 'TextField', 'CheckBox', etc., you MUST provide 'label'.
    """

    public static let textMathRules = """
    - Math formulas MUST be LaTeX wrapped in `$...$` (inline) or `$$...$$` (display) inside a 'Text' component whose 'variant' is 'body' or omitted; other variants show them as raw text.
    """
}

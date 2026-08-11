/// Prompt-ready rule blocks that tell a model how to emit a valid A2UI response.
///
/// The rules cover the tags that wrap the JSON and the ordering constraint on the `components`
/// array — constraints a JSON schema cannot express on its own. Pick one delivery rule
/// (`default` or `toolCall`) and append whichever of the topic rules apply to your catalog.
public enum A2UIWorkflowRules {
    /// The delivery rules for A2UI JSON written into the model's text response.
    ///
    /// Matches the Python SDK's `DEFAULT_WORKFLOW_RULES` string verbatim, so a prompt built
    /// here reproduces the official one. Use `toolCall` instead when the model sends UI
    /// through the tool, otherwise the model is told to do both.
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

    /// The delivery rules for the **tool-call** pattern.
    ///
    /// Written for the official `send_a2ui_json_to_client` tool, the counterpart of the Python
    /// SDK's `SendA2uiToClientToolset`. Replaces the tag-wrapping clause of `default` with one
    /// forbidding A2UI JSON in the text response — text that contains it reaches the user as
    /// raw JSON. The ordering and validation constraints are unchanged.
    ///
    /// On error the rules tell the model to repair the payload inside the same turn. That
    /// works because a tool error comes back to the model as a result and does not end the
    /// turn — `TurnEndingTool` ends it only on success — so the recovery path that actually
    /// produces UI is a retry, not an apology.
    public static let toolCall = """
    The generated response MUST follow these rules:
    - You MUST send UI to the client by calling the `send_a2ui_json_to_client` tool with the `a2ui_json` argument set to the A2UI JSON payload.
    - NEVER write A2UI JSON in your text response — not as a fenced code block, not inline. The JSON belongs in the tool argument only; text that contains it is shown to the user as raw JSON.
    - The `a2ui_json` argument MUST be a single, raw JSON array of A2UI messages and MUST validate against the provided A2UI JSON SCHEMA.
    - The tool can be called multiple times in the same turn to render multiple UI surfaces.
    - Around tool calls, you can provide conversational text.
    - Top-Down Component Ordering: Within the `components` list of a message:
        - The 'root' component MUST be the FIRST element.
        - Parent components MUST appear before their child components.
    - The payload will be validated against the A2UI JSON SCHEMA and rejected if it does not conform.
    - If the tool returns an error, read the message, fix the payload, and call the tool again in the SAME turn. Do not apologize instead of retrying.
    """

    /// Data-binding scope rules, transcribed from spec §"Path resolution & scope" (v1.0).
    ///
    /// A JSON schema can express the shape of a template `ChildList` but not its scope
    /// semantics, so without this prose the model writes absolute paths inside a template and
    /// the bindings resolve to nothing. Append it whenever the catalog can produce
    /// template-driven children.
    public static let scopeRules = """
    Data binding scope rules:
    - Paths starting with '/' are ABSOLUTE: they always resolve from the root of the data model, even inside a template.
    - When a container's `children` uses a template ({"componentId": ..., "path": "/items"}), the client instantiates the template once per array element, and inside it any path WITHOUT a leading '/' is RELATIVE to that element (e.g. `name` resolves to /items/0/name, /items/1/name, ...).
    - Therefore, inside template components you MUST bind item fields with relative paths (no leading slash). Use absolute paths there only to reference root-level values.
    - To bind the array element itself (e.g. iterating an array of strings), use {"path": "."}.
    """

    /// A required-property reminder for the **basic catalog** components.
    ///
    /// Mirrors the natural-language hint the Google Python SDK ships alongside the basic
    /// catalog. The same requirements already appear in the schema's `required` arrays, but a
    /// model follows an explicit prose reminder far more reliably — especially for properties
    /// bound to data or written inside a template, which it otherwise omits. This lives in the
    /// library rather than in each app because it is knowledge about the basic catalog.
    public static let basicCatalogRules = """
    Instructions specific to the basic catalog:
    **REQUIRED PROPERTIES:** You MUST include ALL required properties for every component, even if they are inside a template or will be bound to data.
    - For 'Text', you MUST provide 'text'. If dynamic, use { "path": "..." }.
    - For 'Image', you MUST provide 'url'. If dynamic, use { "path": "..." }.
    - For 'Button', you MUST provide 'action'.
    - For 'TextField', 'CheckBox', etc., you MUST provide 'label'.
    """

    /// The rule for LaTeX math delimiters inside a `Text` component.
    ///
    /// Append it when the agent can produce formulas. It also pins the `variant` restriction:
    /// only `body` or an omitted variant renders the math, everything else shows the
    /// delimiters as literal text.
    public static let textMathRules = """
    - Math formulas MUST be LaTeX wrapped in `$...$` (inline) or `$$...$$` (display) inside a 'Text' component whose 'variant' is 'body' or omitted; other variants show them as raw text.
    """
}

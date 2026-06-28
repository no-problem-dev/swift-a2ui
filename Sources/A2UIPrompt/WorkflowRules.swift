/// 全 A2UI システムプロンプトに挿入するデフォルトのワークフロールール群。
///
/// JSON を包むタグ・`components` 配列の順序制約など、LLM が有効な A2UI レスポンスを
/// 生成するための指示。テキストは Python SDK の `DEFAULT_WORKFLOW_RULES` 定数と完全一致。
public enum A2UIWorkflowRules {
    /// Python SDK の `DEFAULT_WORKFLOW_RULES` 文字列と完全一致するデフォルトルールセット。
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

    /// **ツールコール**生成パターン向けのワークフロールール（公式 `send_a2ui_json_to_client`
    /// ツール、Python SDK の `SendA2uiToClientToolset` に対応）。
    ///
    /// `default` のタグ包み条件をツールコール条件に置き換え、順序・バリデーション制約は同じ。
    /// バリデーション/謝罪条件は公式の rizzcharts サンプルの workflow instructions に準拠する。
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

    /// データバインディングのスコープルール（仕様 §"Path resolution & scope"、v0.10）。
    ///
    /// JSON スキーマはテンプレート `ChildList` の形状は表現できるがスコープのセマンティクスは
    /// 表現できないため、モデルがテンプレート内で絶対パスを使用し未解決になることがある。
    /// 仕様の規範的な記述をプロンプト用の散文として移植する。
    public static let scopeRules = """
    Data binding scope rules:
    - Paths starting with '/' are ABSOLUTE: they always resolve from the root of the data model, even inside a template.
    - When a container's `children` uses a template ({"componentId": ..., "path": "/items"}), the client instantiates the template once per array element, and inside it any path WITHOUT a leading '/' is RELATIVE to that element (e.g. `name` resolves to /items/0/name, /items/1/name, ...).
    - Therefore, inside template components you MUST bind item fields with relative paths (no leading slash). Use absolute paths there only to reference root-level values.
    - To bind the array element itself (e.g. iterating an array of strings), use {"path": "."}.
    """

    /// **basic catalog** コンポーネント向けの必須プロパティリマインダー。
    ///
    /// Google Python SDK が basic catalog に付属させる自然言語ヒントのミラー。
    /// 必須プロパティはスキーマの `required` 配列に既に記載されているが、LLM は
    /// 明示的な散文リマインダーの方がより確実に従う。basic catalog のドメイン知識として
    /// 各アプリでなくこのライブラリに置く。
    public static let basicCatalogRules = """
    Instructions specific to the basic catalog:
    **REQUIRED PROPERTIES:** You MUST include ALL required properties for every component, even if they are inside a template or will be bound to data.
    - For 'Text', you MUST provide 'text'. If dynamic, use { "path": "..." }.
    - For 'Image', you MUST provide 'url'. If dynamic, use { "path": "..." }.
    - For 'Button', you MUST provide 'action'.
    - For 'TextField', 'CheckBox', etc., you MUST provide 'label'.
    """

    /// `Text` コンポーネント内の数式 LaTeX デリミタに関するルール。
    public static let textMathRules = """
    - Math formulas MUST be LaTeX wrapped in `$...$` (inline) or `$$...$$` (display) inside a 'Text' component whose 'variant' is 'body' or omitted; other variants show them as raw text.
    """
}

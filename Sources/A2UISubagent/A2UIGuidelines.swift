import Foundation

/// 副エージェントのシステムプロンプトを構成するガイドラインブロック。
///
/// 各ブロックは 3 状態を取る（公式 TS の `undefined` / `""` / 値 の per-field
/// フォールバックに対応）。Swift では `String?` で 2 状態しか表現できないため
/// enum にする。
public enum A2UIGuidelineBlock: Sendable, Equatable {
    /// 組み込みの既定文言を使う。
    case `default`
    /// このブロックを出力しない（ホストが明示的に抑止する）。
    case suppressed
    /// 独自の文言に差し替える。
    case custom(String)

    /// 既定値を渡して実際の文字列を解決する。抑止時は `nil`。
    func resolve(default defaultValue: String) -> String? {
        switch self {
        case .default: defaultValue.isEmpty ? nil : defaultValue
        case .suppressed: nil
        case .custom(let value): value.isEmpty ? nil : value
        }
    }
}

/// 副エージェントに渡すガイドライン一式。
public struct A2UIGuidelines: Sendable, Equatable {
    /// A2UI プロトコル規則（ID / パス / データバインディング）。
    public var generation: A2UIGuidelineBlock
    /// 視覚設計の指針。プロダクト固有のテーマはここを差し替える。
    public var design: A2UIGuidelineBlock
    /// ホスト固有のカタログ知識（カスタムコンポーネントの使い分け等）。既定なし。
    public var composition: String?

    public init(
        generation: A2UIGuidelineBlock = .default,
        design: A2UIGuidelineBlock = .default,
        composition: String? = nil
    ) {
        self.generation = generation
        self.design = design
        self.composition = composition
    }

    public static let `default` = A2UIGuidelines()
}

/// 公式 `DEFAULT_GENERATION_GUIDELINES` / `DEFAULT_DESIGN_GUIDELINES` に対応する既定文言。
///
/// 各ルールは検証器（`A2UIValidation`）のエラーと 1 対 1 で対応させる意図で書かれている
/// — プロンプトで言ったことを検証が必ずチェックし、違反がエラーとしてプロンプトに戻る
/// 閉じたループを作るため。
public enum A2UIDefaultGuidelines {
    /// ツール名を埋め込んで生成ガイドラインを組み立てる。
    public static func generation(renderToolName: String = A2UISubagentConstants.renderToolName) -> String {
        """
        Generate A2UI JSON.

        ## A2UI Protocol Instructions

        A2UI (Agent to UI) is a protocol for rendering rich UI surfaces from agent responses.

        CRITICAL: You MUST call the \(renderToolName) tool with ALL of these arguments:
        - surfaceId: A unique ID for the surface (e.g. "product-comparison")
        - components: REQUIRED — the A2UI component array. NEVER omit this. Use a List with
          children: { componentId: "card-id", path: "/items" } for repeating cards.
        - data: OPTIONAL — a JSON object written to the root of the surface data model.
          Use for pre-filling form values or providing data for path-bound components.
        - every component must have the "component" field specifying the component type
          (e.g. "Text", "Image", "Row", "Column", "List", "Button", etc.)

        COMPONENT ORDERING:
        - The 'root' component MUST be the FIRST element of the components array.
        - Parent components MUST appear before their child components.
          This ordering lets the renderer build the UI incrementally as it arrives.

        COMPONENT ID RULES:
        - Every component ID must be unique within the surface.
        - A component MUST NOT reference itself as child/children. This causes a
          circular dependency error. For example, if a component has id="avatar",
          its child must be a DIFFERENT id (e.g. "avatar-img"), never "avatar".
        - The child/children tree must be a DAG — no cycles allowed.

        PATH RULES FOR TEMPLATES:
        Components inside a repeating List use RELATIVE paths (no leading slash).
        The path is resolved relative to each array item automatically.
        If List has children: { componentId: "card", path: "/items" } and item has key "name",
        use { "path": "name" } (NO leading slash — relative to item).
        CRITICAL: Do NOT use "/name" (absolute) inside templates — use "name" (relative).
        The List's own path ("/items") uses a leading slash (absolute), but all
        components INSIDE the template card use paths WITHOUT leading slash.
        Do NOT use "/items/0/name" or "/items/{@key}/name" — just "name".

        DATA MODEL:
        The "data" argument is a plain JSON object that initializes the surface data model.
        Components bound to paths (e.g. "value": { "path": "/form/name" }) read from and
        write to this data model. Examples:
          For lists:  "data": { "items": [{"name": "Product A"}, {"name": "Product B"}] }
          For forms:  "data": { "form": { "name": "Alice", "email": "" } }

        FORMS AND TWO-WAY DATA BINDING:
        To create editable forms, bind input components to data model paths using { "path": "..." }.
        The client automatically writes user input back to the data model at the bound path.
        CRITICAL: Using a literal value (e.g. "value": "") makes the field READ-ONLY.
        You MUST use { "path": "..." } to make inputs editable.

        To retrieve form values when a button is clicked, include "context" with path references
        in the button's action. Paths are resolved to their current values at click time:
          "action": { "event": { "name": "submit", "context": { "userName": { "path": "/form/name" } } } }
        """
    }

    /// 視覚設計の既定指針。
    public static let design = """
    Create polished, visually appealing interfaces:
    - Always include a title heading for the surface, outside any List.
      Wrap in a Column: [title, list] as root.
    - For card templates, create clear visual hierarchy. `variant` is only
      "caption" or "body"; express headings with Markdown in the text itself:
      - "## " prefix for primary text (names, titles)
      - "**bold**" for featured numbers (prices, scores) — makes them stand out
      - caption for secondary info (ratings, categories, metadata)
      - body for descriptions
    - Use Divider between logical sections within cards.
    - Use Row with justify="spaceBetween" for label-value pairs.
    - Keep cards clean — avoid clutter. Whitespace is good.
    - Use consistent surfaceIds (lowercase, hyphenated).
    - NEVER use the same ID for a component and its child — this creates a
      circular dependency. E.g. if id="avatar", child must NOT be "avatar".
    - Add Button for interactivity. Button needs child (Text ID) + action.
      Action MUST use this exact nested format:
        "action": { "event": { "name": "myAction", "context": { "key": "value" } } }
      The "event" key holds an OBJECT with "name" (required) and "context" (optional).
      Do NOT use a flat format like {"event": "name"} — "event" must be an object.
    """
}

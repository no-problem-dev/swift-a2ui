import Foundation

/// 2 段構成（外側 `generate_a2ui` / 内側 `render_a2ui`）のワイヤ定数。
///
/// ミラー元: `@ag-ui/a2ui-toolkit` の `index.ts`。ツール名・引数名は公式と
/// バイト一致させる（プロンプト・履歴・エンベロープをまたぐ契約なので、
/// 表記の揺れはそのまま相互運用の破綻になる）。
public enum A2UISubagentConstants {
    /// メインのプランナーに見せる外側ツール名。
    public static let generateToolName = "generate_a2ui"
    /// 副エージェントに強制する内側ツール名。
    public static let renderToolName = "render_a2ui"
    /// エンベロープのオペレーション配列キー。
    public static let operationsKey = "a2ui_operations"
    /// 既定の surfaceId（モデルが空文字を返した場合のフォールバック）。
    public static let defaultSurfaceId = "dynamic-surface"
    /// リトライ打ち切り時のエラーコード。
    public static let recoveryExhaustedCode = "a2ui_recovery_exhausted"

    /// 外側ツールの説明（メインのプランナー向け）。
    public static let generateToolDescription =
        "Generate or update a dynamic A2UI surface based on the conversation. "
            + "A secondary LLM designs the UI components and data. "
            + "Use intent='create' (default) when the user requests new visual content "
            + "(cards, forms, lists, dashboards, comparisons, etc.). "
            + "Use intent='update' with target_surface_id to modify a surface you "
            + "previously rendered (e.g. 'change the second card's price', "
            + "'add a Buy button', 'use red instead of blue')."

    /// 外側ツールの引数説明。
    public enum GenerateArgDescriptions {
        public static let intent =
            "'create' to render a new surface; 'update' to modify a surface previously rendered "
                + "in this conversation. Defaults to 'create'."
        public static let targetSurfaceId =
            "Required when intent='update'. The surface id of the prior render to modify."
        public static let changes =
            "Optional natural-language description of the changes to apply when intent='update'."
    }
}

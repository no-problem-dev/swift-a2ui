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
    /// surfaceId の接頭辞。実際の ID は `newSurfaceId()` が発行する。
    public static let surfaceIdPrefix = "surface"
    /// リトライ打ち切り時のエラーコード。
    public static let recoveryExhaustedCode = "a2ui_recovery_exhausted"

    /// このターンのサーフェス ID を発行する。
    ///
    /// 仕様は `surfaceId` がレンダラの生存期間で一意であることを要求する（既存 ID への
    /// 削除なしの再作成はエラー）。アペンドオンリーでは毎ターン新しいサーフェスを作るので、
    /// ホストが UUID で発行してモデルには選ばせない。
    public static func newSurfaceId() -> String {
        "\(surfaceIdPrefix)-\(UUID().uuidString.lowercased())"
    }

    /// 外側ツールの説明（メインのプランナー向け）。
    ///
    /// 更新はできない（アペンドオンリー）。過去のサーフェスを書き換える言い回しを載せると
    /// モデルがそれを試みるので、「新しく描く」ことだけを説明する。
    public static let generateToolDescription =
        "Render a new dynamic A2UI surface based on the conversation. "
            + "A secondary LLM designs the UI components and data. "
            + "Use when the user requests visual content "
            + "(cards, forms, lists, dashboards, comparisons, etc.). "
            + "Each call renders a NEW surface appended to the conversation; previously "
            + "rendered surfaces are never modified. To show revised content, render a new "
            + "surface carrying the updated information."

    /// 外側ツールの引数説明。
    public enum GenerateArgDescriptions {
        public static let intent =
            "Optional natural-language description of what to render "
                + "(e.g. 'a comparison of the three recipes we found')."
    }
}

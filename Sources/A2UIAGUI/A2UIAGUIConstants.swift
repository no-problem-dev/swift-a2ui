/// AG-UI 上で A2UI を運ぶための wire 定数。
///
/// ミラー元: ag-ui リポジトリの公式 `middlewares/a2ui-middleware`(`src/index.ts` /
/// `src/tools.ts`)。文字列はバイト一致が要求される wire contract であり、散文ではない。
public enum A2UIAGUIConstants {
    /// `ACTIVITY_SNAPSHOT.activityType` の判別値。
    public static let activityType = "a2ui-surface"

    /// paint スナップショットの content キー。値は A2UI エンベロープ
    /// (`{version, <op 1 つ>}`)の配列。
    public static let operationsKey = "a2ui_operations"

    /// クライアントが A2UI 対応を宣言する `RunAgentInput.context` エントリの
    /// description。ミドルウェアは**完全一致**で判別する(`—` は U+2014)。
    public static let schemaContextDescription =
        "A2UI Component Schema — available components for generating UI surfaces. "
            + "Use these component names and properties when creating A2UI operations."

    /// エージェント(サーバー側)に注入するレンダリングツール名。
    public static let renderToolName = "render_a2ui"

    /// プランナー向けの外側ツール名。
    public static let generateToolName = "generate_a2ui"

    /// ユーザーアクションを会話履歴に固定する合成ツール名
    /// (エージェントに宣言されるツールではない)。
    public static let logActionToolName = "log_a2ui_event"

    /// 単一 surface の messageId。tool call 単位でライフサイクル
    /// (building → retrying → paint)全体が 1 メッセージに乗る。
    public static func surfaceMessageId(toolCallId: String) -> String {
        "a2ui-surface-\(toolCallId)"
    }

    /// 複数 surface のときの messageId(surfaceId ごとに 1 スナップショット)。
    public static func surfaceMessageId(surfaceId: String, toolCallId: String) -> String {
        "a2ui-surface-\(surfaceId)-\(toolCallId)"
    }
}

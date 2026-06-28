/// 公式 A2UI ツールコール生成パターンの定数群 — Python SDK の `a2ui.schema.constants`
/// ツールブロック（`A2UI_TOOL_NAME` 等）に対応する Swift 版。
public enum A2UIToolConstants {
    /// LLM がクライアントへ UI を送信する際に呼び出す関数名。
    public static let toolName = "send_a2ui_json_to_client"
    /// 検証成功時にペイロードを格納するリザルトキー。
    public static let validatedJSONKey = "validated_a2ui_json"
    /// 失敗内容を格納するリザルトキー（モデルに返す。クライアントには渡さない）。
    public static let errorKey = "error"
    /// ツールの唯一の必須文字列引数。
    public static let jsonArgName = "a2ui_json"
}

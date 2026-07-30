import A2UICore
import Foundation

/// ツール結果から A2UI オペレーションを抽出する（2 段構成用）。
///
/// `generate_a2ui` の成功結果のみが UI を持つ。エラー結果は破棄する
/// （クライアントに表示せず、モデルが同一ループ内で自己修正する）。
public enum A2UIOperationsExtractor {

    /// 指定のツール結果から A2UI メッセージを抽出して返す。対象外の場合は nil。
    ///
    /// - Parameters:
    ///   - name: ツール名。既定の `generate_a2ui` 以外を使う場合は `toolName` で指定する。
    ///   - output: ツール結果の文字列（`{"a2ui_operations": [...]}` を期待する）。
    ///   - isError: ツールがエラーを返したか。
    ///   - toolName: 照合するツール名。
    public static func messages(
        fromToolResult name: String,
        output: String,
        isError: Bool,
        toolName: String = A2UISubagentConstants.generateToolName
    ) -> [ServerMessage]? {
        guard name == toolName, !isError else { return nil }
        struct Envelope: Decodable { let a2ui_operations: [ServerMessage] }
        guard let envelope = try? JSONDecoder().decode(Envelope.self, from: Data(output.utf8)) else {
            return nil
        }
        return envelope.a2ui_operations
    }
}

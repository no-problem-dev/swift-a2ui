import Foundation
import A2UICore

/// ツール結果からクライアント向け A2UI メッセージを抽出する — Python SDK の
/// `A2uiPartConverter` ツールレスポンスパスの Swift 対応。
///
/// `send_a2ui_json_to_client` の成功結果のみが UI を持つ。エラー結果は破棄し
/// （クライアントに表示しない — モデルがワークフロー規則に従って謝罪する）、
/// 他ツールの結果は無視する。
public enum A2UIToolResultExtractor {

    /// 指定のツール結果から A2UI サーバメッセージを抽出して返す。対象外の場合は nil。
    public static func messages(fromToolResult name: String, output: String, isError: Bool) -> [ServerMessage]? {
        guard name == A2UIToolConstants.toolName, !isError else { return nil }
        struct Payload: Decodable { let validated_a2ui_json: [ServerMessage] }
        guard let payload = try? JSONDecoder().decode(Payload.self, from: Data(output.utf8)) else { return nil }
        return payload.validated_a2ui_json
    }
}

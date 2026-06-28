import Foundation
import A2UICore

/// **ツール引数** として渡された A2UI ペイロードの厳格なパーサ — 公式 Python
/// `payload_fixer.parse_and_fix()` の Swift 対応。
///
/// Python SDK と同じ自動修正（スマートクォート正規化、初回パース失敗時の末尾カンマ除去）を
/// 適用し、単一メッセージオブジェクトを配列でラップする。`A2UIBlockParser` の寛容な要素単位
/// 復旧とは異なり、**厳格モード**: デコード不可能なペイロードはスローし、エラーをモデルへの
/// ツールエラーとして返すことで自己修正を促す。
public enum A2UIPayloadFixer {

    public struct ParseError: Error, CustomStringConvertible {
        public let description: String
    }

    /// LLM から渡された生 JSON 文字列を検証・自動修正し、デコードされたメッセージを返す。
    public static func parseAndFix(_ payload: String) throws -> [ServerMessage] {
        let normalized = normalizeSmartQuotes(payload)
        if let messages = decodeStrict(normalized) {
            return messages
        }
        if let messages = decodeStrict(removeTrailingCommas(normalized)) {
            return messages
        }
        // LaTeX-heavy content frequently arrives with under-escaped backslashes ("\infty"
        // instead of "\\infty"), which is invalid JSON. Repair invalid escapes and retry.
        let repaired = repairInvalidEscapes(normalized)
        if let messages = decodeStrict(repaired) {
            return messages
        }
        if let messages = decodeStrict(removeTrailingCommas(repaired)) {
            return messages
        }
        throw ParseError(description: "Failed to parse JSON: payload is not a valid A2UI message or array of messages. "
            + "If string values contain LaTeX, every backslash must be escaped for JSON (write \\\\int, not \\int).")
    }

    // MARK: - Private

    /// `[ServerMessage]` としてデコードし、単一オブジェクトを配列でラップする（Python `_parse` 相当）。
    private static func decodeStrict(_ json: String) -> [ServerMessage]? {
        let data = Data(json.utf8)
        guard let root = try? JSONParser().parse(data) else { return nil }
        if let messages = try? root.decode([ServerMessage].self) {
            return messages
        }
        if let message = try? root.decode(ServerMessage.self) {
            return [message]
        }
        return nil
    }

    private static func normalizeSmartQuotes(_ json: String) -> String {
        json.replacingOccurrences(of: "\u{201C}", with: "\"")
            .replacingOccurrences(of: "\u{201D}", with: "\"")
            .replacingOccurrences(of: "\u{2018}", with: "'")
            .replacingOccurrences(of: "\u{2019}", with: "'")
    }

    private static func removeTrailingCommas(_ json: String) -> String {
        json.replacingOccurrences(of: #",(?=\s*[\]}])"#, with: "", options: .regularExpression)
    }

    /// 有効な JSON エスケープ（`\" \\ \/ \b \f \n \r \t \u`）で始まらないバックスラッシュを二重化する。
    /// シングルバックスラッシュで書かれた LaTeX（`\infty` → `\\infty`）を修復する。有効なエスケープはそのまま残す。
    private static func repairInvalidEscapes(_ json: String) -> String {
        json.replacingOccurrences(of: #"\\(?!["\\/bfnrtu])"#, with: #"\\\\"#, options: .regularExpression)
    }
}

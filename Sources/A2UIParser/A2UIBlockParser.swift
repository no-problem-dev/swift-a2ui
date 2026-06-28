import Foundation
import A2UICore

/// LLM のテキスト出力に埋め込まれた `<a2ui-json>` ブロックをパースする。
public enum A2UIBlockParser {
    /// A2UI JSON ブロックを区切る開きタグ。
    public static let openTag = "<a2ui-json>"
    /// A2UI JSON ブロックを区切る閉じタグ。
    public static let closeTag = "</a2ui-json>"

    /// 0 個以上の `<a2ui-json>` ブロックを含むテキストをパースする。
    ///
    /// タグの外側のコンテンツには `.text` パーツを、タグ内のデコード済みコンテンツには
    /// `.messages` パーツを含む `A2UIResponsePart` の配列を返す。
    ///
    /// - Parameter text: パース対象の生 LLM 出力文字列。
    /// - Returns: 順序付きのレスポンスパーツ配列。
    public static func parse(_ text: String) -> [A2UIResponsePart] {
        var parts: [A2UIResponsePart] = []
        var remaining = text[...]

        while let openRange = remaining.range(of: openTag) {
            // Emit text before the open tag
            let textBefore = String(remaining[remaining.startIndex..<openRange.lowerBound])
            let trimmed = textBefore.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                parts.append(.text(trimmed))
            }

            remaining = remaining[openRange.upperBound...]

            // Find the matching closing tag
            guard let closeRange = remaining.range(of: closeTag) else {
                // No closing tag — treat remaining text as plain text
                let rest = String(remaining).trimmingCharacters(in: .whitespacesAndNewlines)
                if !rest.isEmpty {
                    parts.append(.text(rest))
                }
                return parts
            }

            // Extract and decode the JSON block
            let jsonString = String(remaining[remaining.startIndex..<closeRange.lowerBound])
            let sanitized = JSONSanitizer.sanitize(jsonString)

            if let messages = decodeMessages(from: sanitized) {
                parts.append(.messages(messages))
            }

            remaining = remaining[closeRange.upperBound...]
        }

        // Emit any remaining text after the last closing tag
        let rest = String(remaining).trimmingCharacters(in: .whitespacesAndNewlines)
        if !rest.isEmpty {
            parts.append(.text(rest))
        }

        return parts
    }

    // MARK: - Private

    /// JSON 文字列を `ServerMessage` の配列に**寛容な**デコードで変換する。
    /// 単一の不正形式メッセージがサーフェス全体を破棄しないよう耐障害性を持つ
    /// （LLM 出力は部分的に不正である場合が多い）。
    ///
    /// 1. 高速パス — `[ServerMessage]` 配列全体をデコード。
    /// 2. 単一メッセージへのフォールバック。
    /// 3. 寛容パス — トップレベルの配列を解析し各要素を独立してデコード、
    ///    有効なメッセージを残して不正なもの（例: `version` が誤り）をスキップ。
    static func decodeMessages(from json: String) -> [ServerMessage]? {
        guard let data = json.data(using: .utf8) else { return nil }

        // 1) Whole-array fast path.
        if let messages = try? JSONParser().parse(data).decode([ServerMessage].self) {
            return messages
        }

        guard let root = try? JSONParser().parse(data) else { return nil }

        // 2) Single message.
        if let message = try? root.decode(ServerMessage.self) {
            return [message]
        }

        // 3) Resilient per-element decode — keep whatever is valid.
        if case .array(let elements) = root {
            let decoded = elements.compactMap { try? $0.decode(ServerMessage.self) }
            if !decoded.isEmpty { return decoded }
        }

        return nil
    }
}

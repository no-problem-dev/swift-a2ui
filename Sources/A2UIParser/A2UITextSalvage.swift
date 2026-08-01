import A2UICore
import Foundation

/// アシスタントの**テキスト出力**に紛れ込んだ A2UI JSON を救出する。
///
/// ツールコールパターン（`send_a2ui_json_to_client`）では A2UI JSON はツール引数として
/// 届くのが正しく、テキストに混ざるのは指示違反である。しかし小型モデルは
/// 「会話テキスト + JSON」を出す方に倒れることがあり、素通しすると生 JSON が
/// そのままユーザーに表示される。ここで抽出してサーフェスとして扱い、テキストからは
/// 取り除くことで、指示違反を体験の破綻にしない。
///
/// 対応する混入形:
/// - ` ```json … ``` ` / ` ``` … ``` ` のコードフェンス
/// - `<a2ui-json>` … `</a2ui-json>` タグ（`A2UIBlockParser` と同じ形。タグ方式との併用時）
/// - 裸のトップレベル JSON 配列（フェンスもタグもないケース）
///
/// 抽出は「A2UI メッセージとしてデコードできたものだけ」を対象にする。無関係な JSON
/// （レシピ検索結果の引用など）を誤ってサーフェス化しないため、デコード失敗した候補は
/// テキストとして残す。
public enum A2UITextSalvage {

    /// 救済結果。
    public struct Result: Sendable, Equatable {
        /// A2UI として解釈できた部分を取り除いた残りのテキスト。
        public let text: String
        /// 抽出できた A2UI メッセージ（出現順）。
        public let messages: [AgentMessage]

        public init(text: String, messages: [AgentMessage]) {
            self.text = text
            self.messages = messages
        }

        /// 何も抽出できなかったか。
        public var isEmpty: Bool { messages.isEmpty }
    }

    /// テキストから A2UI JSON を抽出し、残りのテキストと併せて返す。
    ///
    /// 何も見つからなければ `messages` が空で `text` は入力のまま（trim のみ）。
    public static func salvage(_ text: String) -> Result {
        var remaining = text
        var collected: [AgentMessage] = []

        // 1) タグ付きブロック（タグ方式との併用や、タグを真似た出力）
        extract(from: &remaining, into: &collected, open: A2UIBlockParser.openTag, close: A2UIBlockParser.closeTag)

        // 2) コードフェンス。```json / ```JSON / ``` のいずれも対象にする
        extractFences(from: &remaining, into: &collected)

        // 3) 裸のトップレベル JSON 配列
        extractBareArrays(from: &remaining, into: &collected)

        return Result(
            text: remaining.trimmingCharacters(in: .whitespacesAndNewlines),
            messages: collected
        )
    }

    // MARK: - Private

    /// 開始／終了マーカーで挟まれた区間を走査し、A2UI としてデコードできたものだけ取り除く。
    private static func extract(
        from text: inout String,
        into collected: inout [AgentMessage],
        open: String,
        close: String
    ) {
        var searchStart = text.startIndex
        while let openRange = text.range(of: open, range: searchStart ..< text.endIndex),
              let closeRange = text.range(of: close, range: openRange.upperBound ..< text.endIndex) {
            let body = String(text[openRange.upperBound ..< closeRange.lowerBound])
            if let messages = decode(body) {
                collected.append(contentsOf: messages)
                text.removeSubrange(openRange.lowerBound ..< closeRange.upperBound)
                searchStart = openRange.lowerBound
            } else {
                // A2UI ではないブロック（他用途のコード片など）はテキストに残す
                searchStart = closeRange.upperBound
            }
        }
    }

    /// コードフェンス（``` で始まり ``` で閉じる区間）を走査する。
    private static func extractFences(from text: inout String, into collected: inout [AgentMessage]) {
        let fence = "```"
        var searchStart = text.startIndex
        while let openRange = text.range(of: fence, range: searchStart ..< text.endIndex) {
            // 開きフェンス直後の言語タグ行を読み飛ばす
            let afterOpen = openRange.upperBound
            let lineEnd = text[afterOpen...].firstIndex(of: "\n") ?? text.endIndex
            let language = text[afterOpen ..< lineEnd].trimmingCharacters(in: .whitespaces)
            let bodyStart = lineEnd == text.endIndex ? text.endIndex : text.index(after: lineEnd)
            guard language.count <= 8,
                  let closeRange = text.range(of: fence, range: bodyStart ..< text.endIndex) else {
                searchStart = openRange.upperBound
                continue
            }
            let body = String(text[bodyStart ..< closeRange.lowerBound])
            if let messages = decode(body) {
                collected.append(contentsOf: messages)
                text.removeSubrange(openRange.lowerBound ..< closeRange.upperBound)
                searchStart = openRange.lowerBound
            } else {
                searchStart = closeRange.upperBound
            }
        }
    }

    /// 裸のトップレベル JSON 配列を走査する。`[` から対応する `]` までを候補にする。
    private static func extractBareArrays(from text: inout String, into collected: inout [AgentMessage]) {
        var searchStart = text.startIndex
        while let openIndex = text[searchStart...].firstIndex(of: "[") {
            guard let closeIndex = matchingBracket(in: text, from: openIndex) else {
                return
            }
            let body = String(text[openIndex ... closeIndex])
            if let messages = decode(body) {
                collected.append(contentsOf: messages)
                let next = text.index(after: closeIndex)
                text.removeSubrange(openIndex ..< next)
                searchStart = openIndex
            } else {
                searchStart = text.index(after: openIndex)
            }
            if searchStart >= text.endIndex {
                return
            }
        }
    }

    /// `[` に対応する `]` を、文字列リテラルとエスケープを考慮して探す。
    private static func matchingBracket(in text: String, from openIndex: String.Index) -> String.Index? {
        var depth = 0
        var inString = false
        var index = openIndex
        while index < text.endIndex {
            let c = text[index]
            if inString {
                if c == "\\" {
                    index = text.index(after: index)
                    if index >= text.endIndex { return nil }
                } else if c == "\"" {
                    inString = false
                }
            } else {
                switch c {
                case "\"": inString = true
                case "[": depth += 1
                case "]":
                    depth -= 1
                    if depth == 0 { return index }
                default: break
                }
            }
            index = text.index(after: index)
        }
        return nil
    }

    /// A2UI メッセージとしてデコードできる場合のみ返す（サニタイズ込み）。
    private static func decode(_ body: String) -> [AgentMessage]? {
        let trimmed = body.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        guard let messages = A2UIBlockParser.decodeMessages(from: JSONSanitizer.sanitize(trimmed)),
              !messages.isEmpty else {
            return nil
        }
        return messages
    }
}

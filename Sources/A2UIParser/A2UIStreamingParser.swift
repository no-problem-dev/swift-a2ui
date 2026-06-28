import Foundation
import A2UICore

/// ストリーミング LLM 出力をインクリメンタルにパースし、完全なレスポンスを待たずに
/// `<a2ui-json>` ブロックが到着した時点で抽出する。
///
/// 使い方:
/// ```swift
/// let parser = A2UIStreamingParser()
/// for chunk in stream {
///     let parts = parser.feed(chunk)
///     // process parts
/// }
/// let finalParts = parser.finalize()
/// ```
public final class A2UIStreamingParser: @unchecked Sendable {
    private var buffer: String = ""

    public init() {}

    /// LLM ストリームのテキストチャンクを受け取る。
    ///
    /// 蓄積済みバッファから抽出できる完結した `A2UIResponsePart` を返す。
    /// 最初の開きタグより前のテキストは、完結したブロックが見つかるか `finalize()` が
    /// 呼ばれるまで保留される。
    ///
    /// - Parameter chunk: ストリームからの新しいテキストチャンク。
    /// - Returns: 0 個以上の完結したレスポンスパーツ。
    public func feed(_ chunk: String) -> [A2UIResponsePart] {
        buffer.append(chunk)
        return extractCompleteParts()
    }

    /// ストリーム終了後、バッファに残ったコンテンツをフラッシュする。
    ///
    /// LLM ストリームが完了したら一度だけ呼び出す。完結した `<a2ui-json>` ブロックを
    /// 含まないバッファ済みテキストは `.text` パーツとして返される。
    ///
    /// - Returns: 残りバッファコンテンツの 0 個以上のレスポンスパーツ。
    public func finalize() -> [A2UIResponsePart] {
        defer { buffer = "" }
        let remaining = buffer.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !remaining.isEmpty else { return [] }
        return [.text(remaining)]
    }

    /// パーサを初期状態にリセットし、バッファ済みコンテンツを破棄する。
    public func reset() {
        buffer = ""
    }

    // MARK: - Private

    /// バッファの先頭から完結した開きタグ＋閉じタグのペアをすべて抽出し、
    /// テキストとメッセージパーツを発行する。不完全なコンテンツ（例: 閉じタグのない
    /// 開きタグ）は次回の `feed` 呼び出しのためにバッファに残す。
    private func extractCompleteParts() -> [A2UIResponsePart] {
        var parts: [A2UIResponsePart] = []

        while let openRange = buffer.range(of: A2UIBlockParser.openTag),
              let closeRange = buffer[openRange.upperBound...].range(of: A2UIBlockParser.closeTag) {

            // Emit text before the open tag
            let textBefore = String(buffer[buffer.startIndex..<openRange.lowerBound])
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if !textBefore.isEmpty {
                parts.append(.text(textBefore))
            }

            // Extract and decode the JSON block (resilient: keeps valid messages if some are bad).
            let jsonString = String(buffer[openRange.upperBound..<closeRange.lowerBound])
            let sanitized = JSONSanitizer.sanitize(jsonString)
            if let messages = A2UIBlockParser.decodeMessages(from: sanitized) {
                parts.append(.messages(messages))
            }

            // Advance the buffer past the close tag
            buffer = String(buffer[closeRange.upperBound...])
        }

        return parts
    }
}

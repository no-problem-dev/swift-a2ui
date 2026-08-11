import JSONParsing
import StructuredDataCore
import Foundation
import A2UICore

/// Splits a complete LLM text response into plain text and the `<a2ui-json>` blocks embedded in it.
///
/// Tolerant on purpose, because model output is often partly malformed: an open tag with no close
/// tag turns the rest of the input into plain text, and a block whose JSON never decodes still
/// yields a part — a `.malformed` one — rather than vanishing. Use `A2UIPayloadFixer` where a
/// failure has to stop the parse instead of being reported alongside what did work.
public enum A2UIBlockParser {
    /// Opening delimiter of an A2UI JSON block, shared with `A2UIStreamingParser` and
    /// `A2UITextSalvage` so every path agrees on where a block starts.
    public static let openTag = "<a2ui-json>"
    /// Closing delimiter of an A2UI JSON block; text after the last one is emitted as a text part.
    public static let closeTag = "</a2ui-json>"

    /// Parses text holding zero or more `<a2ui-json>` blocks.
    ///
    /// Content outside the tags becomes `.text` parts and decoded content inside them becomes
    /// `.messages` parts, interleaved in source order. Text runs that are only whitespace are
    /// dropped. A block that fails to decode becomes a `.malformed` part carrying its raw content,
    /// so an empty result now means what it says — the input held no A2UI — instead of also
    /// covering the case where every block was unreadable.
    ///
    /// - Parameter text: The raw LLM output to parse.
    /// - Returns: The response parts in the order they appeared.
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

            let decoded = decodeMessages(from: sanitized)
            if !decoded.messages.isEmpty {
                parts.append(.messages(decoded.messages))
            }
            if decoded.skipped > 0 || decoded.messages.isEmpty {
                parts.append(.malformed(A2UIMalformedBlock(raw: jsonString, skipped: decoded.skipped)))
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

    /// Decodes a JSON string into `AgentMessage` values **leniently**, so that one malformed
    /// message does not throw away the whole surface (LLM output is often partly invalid).
    ///
    /// 1. Fast path — decode the whole `[AgentMessage]` array.
    /// 2. Fall back to a single message.
    /// 3. Lenient path — parse the top-level array and decode each element on its own, keeping
    ///    the valid messages and skipping the bad ones (a wrong `version`, for example).
    ///
    /// `skipped` counts what step 3 had to drop, so a caller can tell a fully valid array from one
    /// that lost half its messages. Empty messages with `skipped` 0 means nothing decoded at all.
    static func decodeMessages(from json: String) -> (messages: [AgentMessage], skipped: Int) {
        guard let data = json.data(using: .utf8) else { return ([], 0) }

        // 1) Whole-array fast path.
        if let messages = try? JSONParser().parse(data).decode([AgentMessage].self) {
            return (messages, 0)
        }

        guard let root = try? JSONParser().parse(data) else { return ([], 0) }

        // 2) Single message.
        if let message = try? root.decode(AgentMessage.self) {
            return ([message], 0)
        }

        // 3) Resilient per-element decode — keep whatever is valid, and say what was lost.
        if case .array(let elements) = root {
            let decoded = elements.compactMap { try? $0.decode(AgentMessage.self) }
            if !decoded.isEmpty { return (decoded, elements.count - decoded.count) }
        }

        return ([], 0)
    }
}

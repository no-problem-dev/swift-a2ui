import JSONParsing
import StructuredDataCore
import Foundation
import A2UICore

/// Splits a complete LLM text response into plain text and the `<a2ui-json>` blocks embedded in it.
///
/// Tolerant on purpose, because model output is often partly malformed: a block whose JSON never
/// decodes is dropped without a trace, and an open tag with no close tag turns the rest of the
/// input into plain text. Use `A2UIPayloadFixer` where a failure has to be reported instead.
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
    /// dropped, and a block that fails to decode contributes no part, so input made entirely of
    /// undecodable blocks comes back as an empty array rather than an error.
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

    /// Decodes a JSON string into `AgentMessage` values **leniently**, so that one malformed
    /// message does not throw away the whole surface (LLM output is often partly invalid).
    ///
    /// 1. Fast path — decode the whole `[AgentMessage]` array.
    /// 2. Fall back to a single message.
    /// 3. Lenient path — parse the top-level array and decode each element on its own, keeping
    ///    the valid messages and skipping the bad ones (a wrong `version`, for example).
    ///
    /// `nil` means nothing at all decoded. Elements skipped by step 3 are not reported, so a
    /// caller cannot tell a fully valid array from one that lost half its messages.
    static func decodeMessages(from json: String) -> [AgentMessage]? {
        guard let data = json.data(using: .utf8) else { return nil }

        // 1) Whole-array fast path.
        if let messages = try? JSONParser().parse(data).decode([AgentMessage].self) {
            return messages
        }

        guard let root = try? JSONParser().parse(data) else { return nil }

        // 2) Single message.
        if let message = try? root.decode(AgentMessage.self) {
            return [message]
        }

        // 3) Resilient per-element decode — keep whatever is valid.
        if case .array(let elements) = root {
            let decoded = elements.compactMap { try? $0.decode(AgentMessage.self) }
            if !decoded.isEmpty { return decoded }
        }

        return nil
    }
}

import Foundation
import A2UICore

/// Parses `<a2ui-json>` blocks embedded in LLM text output.
public enum A2UIBlockParser {
    /// The opening tag that delimits an A2UI JSON block.
    public static let openTag = "<a2ui-json>"
    /// The closing tag that delimits an A2UI JSON block.
    public static let closeTag = "</a2ui-json>"

    /// Parse text containing zero or more `<a2ui-json>` blocks.
    ///
    /// Returns an array of `A2UIResponsePart` values — `.text` parts for content
    /// outside the tags, and `.messages` parts for decoded content inside the tags.
    ///
    /// - Parameter text: The raw LLM output string to parse.
    /// - Returns: An ordered array of response parts.
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

    /// Decode a JSON string into `ServerMessage`s, **resiliently**: a single malformed message must
    /// not discard the whole surface (LLM output is frequently partially-invalid).
    ///
    /// 1. Fast path — decode the whole `[ServerMessage]` array.
    /// 2. Single-message fallback.
    /// 3. Resilient path — parse the top-level array and decode **each element independently**,
    ///    keeping the valid messages and skipping the bad ones (e.g. one wrong `version`).
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

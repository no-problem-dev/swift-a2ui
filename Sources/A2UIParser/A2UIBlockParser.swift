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

    /// Attempt to decode a JSON string as an array of `ServerMessage` values,
    /// falling back to a single `ServerMessage` if the array decode fails.
    private static func decodeMessages(from json: String) -> [ServerMessage]? {
        guard let data = json.data(using: .utf8) else { return nil }

        // Try array first (the common LLM output format)
        if let messages = try? JSONDecoder().decode([ServerMessage].self, from: data) {
            return messages
        }

        // Fall back to a single message
        if let message = try? JSONDecoder().decode(ServerMessage.self, from: data) {
            return [message]
        }

        return nil
    }
}

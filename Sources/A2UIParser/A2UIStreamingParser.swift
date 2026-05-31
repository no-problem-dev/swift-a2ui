import Foundation
import A2UICore

/// Incrementally parses streaming LLM output, extracting complete `<a2ui-json>` blocks
/// as they arrive without waiting for the full response.
///
/// Usage:
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

    /// Feed a chunk of text from the LLM stream.
    ///
    /// Returns any complete `A2UIResponsePart` values that can be extracted from
    /// the accumulated buffer. Text before the first open tag is held until a
    /// complete block is found or `finalize()` is called.
    ///
    /// - Parameter chunk: A new chunk of text from the stream.
    /// - Returns: Zero or more complete response parts.
    public func feed(_ chunk: String) -> [A2UIResponsePart] {
        buffer.append(chunk)
        return extractCompleteParts()
    }

    /// Flush any remaining buffered content after the stream ends.
    ///
    /// Call this once the LLM stream is complete. Any buffered text that does not
    /// contain a complete `<a2ui-json>` block is returned as a `.text` part.
    ///
    /// - Returns: Zero or more response parts for the remaining buffer content.
    public func finalize() -> [A2UIResponsePart] {
        defer { buffer = "" }
        let remaining = buffer.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !remaining.isEmpty else { return [] }
        return [.text(remaining)]
    }

    /// Reset the parser to its initial state, discarding any buffered content.
    public func reset() {
        buffer = ""
    }

    // MARK: - Private

    /// Extract all complete open+close tag pairs from the front of the buffer,
    /// emitting text and message parts. Leaves incomplete content (e.g., an open
    /// tag with no matching close tag) in the buffer for the next `feed` call.
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

            // Extract and decode the JSON block
            let jsonString = String(buffer[openRange.upperBound..<closeRange.lowerBound])
            let sanitized = JSONSanitizer.sanitize(jsonString)

            if let data = sanitized.data(using: .utf8) {
                if let messages = try? JSONParser().parse(data).decode([ServerMessage].self) {
                    parts.append(.messages(messages))
                } else if let message = try? JSONParser().parse(data).decode(ServerMessage.self) {
                    parts.append(.messages([message]))
                }
            }

            // Advance the buffer past the close tag
            buffer = String(buffer[closeRange.upperBound...])
        }

        return parts
    }
}

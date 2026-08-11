import Foundation
import A2UICore

/// Parses streaming LLM output incrementally, emitting each `<a2ui-json>` block the moment its
/// closing tag arrives rather than waiting for the whole response.
///
/// Text ahead of the first block is withheld until a complete block turns up, so `finalize()` is
/// mandatory: a response that contains no block at all yields nothing until it is called.
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

    /// Appends a text chunk from the LLM stream and returns whatever the buffer can now complete.
    ///
    /// Text before the first open tag stays buffered until a complete block is found or
    /// `finalize()` runs, so early chunks of pure prose return an empty array.
    ///
    /// - Parameter chunk: The new text chunk from the stream.
    /// - Returns: Zero or more complete response parts, in order.
    public func feed(_ chunk: String) -> [A2UIResponsePart] {
        buffer.append(chunk)
        return extractCompleteParts()
    }

    /// Flushes whatever is still buffered once the stream has ended.
    ///
    /// Call once after the LLM stream completes. Buffered text that never formed a complete
    /// `<a2ui-json>` block comes back as a `.text` part — including a block that was opened but
    /// never closed, whose raw JSON is returned as text.
    ///
    /// - Returns: Zero or more response parts for the remaining buffer.
    public func finalize() -> [A2UIResponsePart] {
        defer { buffer = "" }
        let remaining = buffer.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !remaining.isEmpty else { return [] }
        return [.text(remaining)]
    }

    /// Returns the parser to its initial state, discarding the buffer. Anything not yet emitted
    /// is lost, so call `finalize()` first if the buffered text still matters.
    public func reset() {
        buffer = ""
    }

    // MARK: - Private

    /// Takes every complete open-tag/close-tag pair from the front of the buffer and emits the
    /// text and message parts for it. Incomplete content — an open tag whose close tag has not
    /// arrived — stays in the buffer for the next `feed` call.
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

import A2UICore
import Foundation

/// Rescues A2UI JSON that leaked into the assistant's **text output**.
///
/// Under the tool-call pattern (`send_a2ui_json_to_client`) A2UI JSON belongs in a tool argument;
/// putting it in the text is a violation of the instructions. Small models nonetheless fall back
/// to emitting "chat text plus JSON", and passing that straight through shows raw JSON to the
/// user. Extracting it here — treating it as a surface and taking it out of the text — keeps a
/// disobeyed instruction from becoming a broken experience.
///
/// The shapes it handles:
/// - Code fences, ` ```json … ``` ` or ` ``` … ``` `
/// - `<a2ui-json>` … `</a2ui-json>` tags, the same delimiters `A2UIBlockParser` uses, for when
///   the tag pattern runs alongside the tool
/// - A bare top-level JSON array, with neither fence nor tag
///
/// Only candidates that actually decode as A2UI messages are pulled out. Unrelated JSON — a
/// quoted recipe-search result, say — must not be turned into a surface, so a candidate that
/// fails to decode is left in the text.
public enum A2UITextSalvage {

    /// What salvage produced: the text with every extracted block cut out, and the messages taken
    /// from those blocks.
    public struct Result: Sendable, Equatable {
        /// The input with every block that decoded as A2UI removed, then trimmed. Candidates that
        /// failed to decode are still in here.
        public let text: String
        /// The extracted A2UI messages, in the order they appeared in the text.
        public let messages: [AgentMessage]

        public init(text: String, messages: [AgentMessage]) {
            self.text = text
            self.messages = messages
        }

        /// `true` when nothing was extracted. `text` can be non-empty either way, so test this
        /// rather than `text` before deciding to render the turn as plain text.
        public var isEmpty: Bool { messages.isEmpty }
    }

    /// Extracts A2UI JSON from text and returns it beside what is left of the text.
    ///
    /// With nothing found, `messages` is empty and `text` is the input unchanged apart from
    /// trimming.
    ///
    /// - Parameter text: The assistant's raw text output.
    public static func salvage(_ text: String) -> Result {
        var remaining = text
        var collected: [AgentMessage] = []

        // 1) Tagged blocks — the tag pattern in use, or a model imitating the tags.
        extract(from: &remaining, into: &collected, open: A2UIBlockParser.openTag, close: A2UIBlockParser.closeTag)

        // 2) Code fences: ```json, ```JSON and a bare ``` all count.
        extractFences(from: &remaining, into: &collected)

        // 3) Bare top-level JSON arrays.
        extractBareArrays(from: &remaining, into: &collected)

        return Result(
            text: remaining.trimmingCharacters(in: .whitespacesAndNewlines),
            messages: collected
        )
    }

    // MARK: - Private

    /// Walks the spans between the open and close markers, removing only the ones that decode as
    /// A2UI and resuming after a span that does not.
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
                // Not A2UI — a code snippet for something else. Leave it in the text.
                searchStart = closeRange.upperBound
            }
        }
    }

    /// Walks code fences — a span opened by a triple-backtick run and closed by the next one.
    /// A header longer than eight characters is read as prose, not a language tag, and skipped.
    private static func extractFences(from text: inout String, into collected: inout [AgentMessage]) {
        let fence = "```"
        var searchStart = text.startIndex
        while let openRange = text.range(of: fence, range: searchStart ..< text.endIndex) {
            // Skip the language tag line that follows the opening fence.
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

    /// Walks bare top-level JSON arrays, taking each `[` through its matching `]` as a candidate.
    /// An unmatched `[` ends the scan, leaving the rest of the text alone.
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

    /// Finds the `]` that matches a `[`, tracking string literals and their escapes so a bracket
    /// inside a string value cannot close the array. `nil` when the array is never closed.
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

    /// Returns messages only when the body sanitizes and decodes as A2UI. An empty decode counts
    /// as failure, which is what keeps a non-A2UI candidate in the text.
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

import JSONParsing
import StructuredDataCore
import Foundation
import A2UICore

/// Strict parser for an A2UI payload that arrived as a **tool argument** — the Swift counterpart
/// of the official Python `payload_fixer.parse_and_fix()`.
///
/// Preprocessing goes through `JSONSanitizer` alone: code fences stripped, typographic delimiters
/// folded, comments removed, trailing commas dropped — each of them only outside string literals.
/// Models mix ```json fences and `// comment` lines into tool arguments as well, so this path gets
/// the same tolerance as the tag path (`A2UIBlockParser`).
///
/// Past that it is **strict**, unlike the per-element salvage `A2UIBlockParser` performs: a
/// payload that will not decode throws instead of yielding a partial result. Hand the error back
/// to the model as a tool error and it can correct itself on the next turn.
public enum A2UIPayloadFixer {

    public struct ParseError: Error, CustomStringConvertible {
        public let description: String
    }

    /// Validates and repairs the raw JSON string a model produced, then decodes it.
    ///
    /// Two attempts are made: the sanitized input, then the same with invalid backslash escapes
    /// doubled. A payload holding a single message object is accepted and wrapped in a one-element
    /// array.
    ///
    /// Trailing commas are dropped by `JSONSanitizer` alone, which does it with a scanner that
    /// knows where the string literals are. The regex retry this used to make instead could not
    /// tell a trailing comma from one inside a label reading `pick one, } or ]`, so it ate the
    /// comma out of the label and the payload still decoded — silently altered rather than
    /// rejected, which is the one outcome a repair pass must never produce.
    ///
    /// - Parameter payload: The raw tool-argument string.
    /// - Returns: Every decoded message, in payload order.
    /// - Throws: `ParseError` when no attempt decodes. Its `description` is written to be read by
    ///   the model, and names the LaTeX escaping mistake that causes most failures.
    public static func parseAndFix(_ payload: String) throws -> [AgentMessage] {
        let normalized = JSONSanitizer.sanitize(payload)
        if let messages = decodeStrict(normalized) {
            return messages
        }
        // LaTeX-heavy content frequently arrives with under-escaped backslashes ("\infty"
        // instead of "\\infty"), which is invalid JSON. Repair invalid escapes and retry.
        if let messages = decodeStrict(repairInvalidEscapes(normalized)) {
            return messages
        }
        throw ParseError(description: "Failed to parse JSON: payload is not a valid A2UI message or array of messages. "
            + "If string values contain LaTeX, every backslash must be escaped for JSON (write \\\\int, not \\int).")
    }

    // MARK: - Private

    /// Decodes as `[AgentMessage]`, falling back to a single object wrapped in an array (the
    /// equivalent of Python `_parse`). `nil` on any failure, so the caller can try one more repair.
    private static func decodeStrict(_ json: String) -> [AgentMessage]? {
        let data = Data(json.utf8)
        guard let root = try? JSONParser().parse(data) else { return nil }
        if let messages = try? root.decode([AgentMessage].self) {
            return messages
        }
        if let message = try? root.decode(AgentMessage.self) {
            return [message]
        }
        return nil
    }

    /// Doubles every backslash that does not begin a valid JSON escape (`\" \\ \/ \b \f \n \r \t \u`).
    /// Repairs LaTeX written with single backslashes (`\infty` → `\\infty`) and leaves valid
    /// escapes untouched.
    private static func repairInvalidEscapes(_ json: String) -> String {
        json.replacingOccurrences(of: #"\\(?!["\\/bfnrtu])"#, with: #"\\\\"#, options: .regularExpression)
    }
}

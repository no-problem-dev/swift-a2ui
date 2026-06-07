import Foundation
import A2UICore

/// Strict parser for A2UI payloads passed as a **tool argument** — the Swift counterpart of the
/// official Python `payload_fixer.parse_and_fix()`.
///
/// Applies the same autofixes as the Python SDK (smart-quote normalization, then trailing-comma
/// removal on a failed first parse) and wraps a single message object in an array. Unlike
/// `A2UIBlockParser`'s resilient per-element recovery, this is **strict**: an undecodable payload
/// throws, so the error can flow back to the model as a tool error for self-correction.
public enum A2UIPayloadFixer {

    public struct ParseError: Error, CustomStringConvertible {
        public let description: String
    }

    /// Validate and autofix a raw JSON string from the LLM, returning the decoded messages.
    public static func parseAndFix(_ payload: String) throws -> [ServerMessage] {
        let normalized = normalizeSmartQuotes(payload)
        if let messages = decodeStrict(normalized) {
            return messages
        }
        if let messages = decodeStrict(removeTrailingCommas(normalized)) {
            return messages
        }
        // LaTeX-heavy content frequently arrives with under-escaped backslashes ("\infty"
        // instead of "\\infty"), which is invalid JSON. Repair invalid escapes and retry.
        let repaired = repairInvalidEscapes(normalized)
        if let messages = decodeStrict(repaired) {
            return messages
        }
        if let messages = decodeStrict(removeTrailingCommas(repaired)) {
            return messages
        }
        throw ParseError(description: "Failed to parse JSON: payload is not a valid A2UI message or array of messages. "
            + "If string values contain LaTeX, every backslash must be escaped for JSON (write \\\\int, not \\int).")
    }

    // MARK: - Private

    /// Decode as `[ServerMessage]`, wrapping a single object in an array (Python `_parse`).
    private static func decodeStrict(_ json: String) -> [ServerMessage]? {
        let data = Data(json.utf8)
        guard let root = try? JSONParser().parse(data) else { return nil }
        if let messages = try? root.decode([ServerMessage].self) {
            return messages
        }
        if let message = try? root.decode(ServerMessage.self) {
            return [message]
        }
        return nil
    }

    private static func normalizeSmartQuotes(_ json: String) -> String {
        json.replacingOccurrences(of: "\u{201C}", with: "\"")
            .replacingOccurrences(of: "\u{201D}", with: "\"")
            .replacingOccurrences(of: "\u{2018}", with: "'")
            .replacingOccurrences(of: "\u{2019}", with: "'")
    }

    private static func removeTrailingCommas(_ json: String) -> String {
        json.replacingOccurrences(of: #",(?=\s*[\]}])"#, with: "", options: .regularExpression)
    }

    /// Double any backslash that does not start a valid JSON escape (`\" \\ \/ \b \f \n \r \t \u`).
    /// Repairs LaTeX written with single backslashes (`\infty` → `\\infty`); already-valid escapes
    /// are left untouched.
    private static func repairInvalidEscapes(_ json: String) -> String {
        json.replacingOccurrences(of: #"\\(?!["\\/bfnrtu])"#, with: #"\\\\"#, options: .regularExpression)
    }
}

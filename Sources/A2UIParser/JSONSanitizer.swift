import Foundation

/// Cleans up JSON strings that may contain markdown artifacts from LLM output.
public enum JSONSanitizer {
    /// Remove markdown code fences (` ```json ` or ` ``` `) and trailing commas before `}` or `]`.
    ///
    /// Steps:
    /// 1. Strip leading/trailing whitespace.
    /// 2. If the string starts with ` ```json ` or ` ``` `, remove that opening fence line.
    /// 3. If the string ends with ` ``` `, remove the closing fence.
    /// 4. Remove trailing commas before `}` or `]`.
    public static func sanitize(_ json: String) -> String {
        var result = json.trimmingCharacters(in: .whitespacesAndNewlines)

        // Remove opening code fence line (```json or ```)
        if result.hasPrefix("```") {
            if let newlineIndex = result.firstIndex(of: "\n") {
                result = String(result[result.index(after: newlineIndex)...])
                    .trimmingCharacters(in: .whitespacesAndNewlines)
            } else {
                // The entire string is just a fence — strip it and return empty
                result = ""
            }
        }

        // Remove closing code fence
        if result.hasSuffix("```") {
            result = String(result.dropLast(3))
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }

        // Remove trailing commas before } or ] using regex
        if let regex = try? NSRegularExpression(pattern: ",\\s*([}\\]])") {
            let range = NSRange(result.startIndex..., in: result)
            result = regex.stringByReplacingMatches(in: result, range: range, withTemplate: "$1")
        }

        return result
    }
}

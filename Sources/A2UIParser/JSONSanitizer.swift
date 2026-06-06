import Foundation

public enum JSONSanitizer {
    public static func sanitize(_ json: String) -> String {
        var result = json.trimmingCharacters(in: .whitespacesAndNewlines)

        result = result
            .replacingOccurrences(of: "\u{201C}", with: "\"")
            .replacingOccurrences(of: "\u{201D}", with: "\"")
            .replacingOccurrences(of: "\u{2018}", with: "'")
            .replacingOccurrences(of: "\u{2019}", with: "'")

        if result.hasPrefix("```") {
            if let newlineIndex = result.firstIndex(of: "\n") {
                result = String(result[result.index(after: newlineIndex)...])
                    .trimmingCharacters(in: .whitespacesAndNewlines)
            } else {
                result = ""
            }
        }

        if result.hasSuffix("```") {
            result = String(result.dropLast(3))
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }

        // Strip `//` and `/* */` comments (LLMs frequently add them). Done with a string-aware
        // scanner so `//` inside string values — e.g. `https://…` — is preserved.
        result = stripComments(result)

        if let regex = try? NSRegularExpression(pattern: ",\\s*([}\\]])") {
            let range = NSRange(result.startIndex..., in: result)
            result = regex.stringByReplacingMatches(in: result, range: range, withTemplate: "$1")
        }

        return result
    }

    /// Remove `//` line comments and `/* */` block comments that appear **outside** string literals.
    /// JSON forbids comments, but LLMs routinely emit them; stripping lets the block parse instead of
    /// failing wholesale. String literals (and their escapes) are preserved verbatim, so URLs like
    /// `https://example.com` are untouched.
    static func stripComments(_ s: String) -> String {
        let chars = Array(s)
        var out = ""
        out.reserveCapacity(chars.count)
        var i = 0
        var inString = false
        while i < chars.count {
            let c = chars[i]
            if inString {
                if c == "\\", i + 1 < chars.count {     // keep escaped pair verbatim
                    out.append(c); out.append(chars[i + 1]); i += 2; continue
                }
                out.append(c)
                if c == "\"" { inString = false }
                i += 1
                continue
            }
            if c == "\"" {
                inString = true; out.append(c); i += 1; continue
            }
            if c == "/", i + 1 < chars.count {
                let n = chars[i + 1]
                if n == "/" {                            // line comment → skip to EOL (keep newline)
                    i += 2
                    while i < chars.count && chars[i] != "\n" { i += 1 }
                    continue
                }
                if n == "*" {                            // block comment → skip to closing */
                    i += 2
                    while i + 1 < chars.count && !(chars[i] == "*" && chars[i + 1] == "/") { i += 1 }
                    i += 2
                    continue
                }
            }
            out.append(c); i += 1
        }
        return out
    }
}

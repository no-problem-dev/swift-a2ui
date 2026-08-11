import Foundation

/// Normalizes JSON the way an LLM writes it into something the A2UI parsers accept.
///
/// Applied in order: a leading and a trailing code fence are removed, then a single string-aware
/// pass folds typographic double quotes used as delimiters, drops `//` and `/* */` comments, and
/// drops trailing commas.
///
/// **Every repair is confined to what sits outside a string literal.** The point of the sanitizer is
/// to salvage imperfect model output, but a repair that rewrites a string *value* changes what the
/// agent said and the document still decodes, so nothing downstream can tell. Rewriting `don’t` to
/// `don't`, or eating the comma out of a label reading `pick one, } or ]`, is worse than refusing
/// the document — and neither is a price worth paying, because the delimiter and comment cases the
/// repairs exist for all live outside string literals anyway.
public enum JSONSanitizer {
    /// Returns the normalized form of a raw JSON string.
    ///
    /// Never fails and never reports what it changed, so the result can still be invalid JSON —
    /// the caller finds out only when decoding it.
    public static func sanitize(_ json: String) -> String {
        normalize(stripCodeFence(json))
    }

    /// Removes `//` line comments and `/* */` block comments that sit **outside** string literals.
    ///
    /// JSON forbids comments, but LLMs emit them often enough that dropping them is what keeps the
    /// parse from failing. String literals and their escapes are copied verbatim, so a URL such as
    /// `https://example.com` survives untouched.
    static func stripComments(_ s: String) -> String {
        normalize(s, foldQuotes: false, dropTrailingCommas: false)
    }

    // MARK: - Private

    private static func stripCodeFence(_ json: String) -> String {
        var result = json.trimmingCharacters(in: .whitespacesAndNewlines)

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

        return result
    }

    private static let leftDoubleQuote: Character = "\u{201C}"
    private static let rightDoubleQuote: Character = "\u{201D}"

    /// The one scan that performs every repair, so each one knows where the string literals are.
    ///
    /// Typographic **single** quotes are never touched, in a string or out of one: JSON has no
    /// single-quoted string, so `’` can only ever be someone's apostrophe.
    private static func normalize(
        _ s: String,
        foldQuotes: Bool = true,
        dropTrailingCommas: Bool = true
    ) -> String {
        let chars = Array(s)
        var out = ""
        out.reserveCapacity(chars.count)
        var i = 0
        /// The character that will close the string currently being copied; `nil` outside one.
        /// A string opened with `“` closes on `”`, so a plain `"` inside it stays content.
        var closer: Character?

        while i < chars.count {
            let c = chars[i]

            if let open = closer {
                if c == "\\", i + 1 < chars.count {         // keep the escaped pair verbatim
                    out.append(c); out.append(chars[i + 1]); i += 2; continue
                }
                if c == open {
                    out.append("\"")                        // always close with an ASCII quote
                    closer = nil
                } else {
                    out.append(c)
                }
                i += 1
                continue
            }

            if c == "\"" || (foldQuotes && (c == leftDoubleQuote || c == rightDoubleQuote)) {
                // A typographic quote out here is being used as a delimiter, so fold it — and
                // remember which mark has to close the string, or the first `”` inside a plain
                // `"…"` value would end it early.
                closer = c == leftDoubleQuote ? rightDoubleQuote : c
                out.append("\"")
                i += 1
                continue
            }

            if c == "/", i + 1 < chars.count {
                let n = chars[i + 1]
                if n == "/" {                               // line comment → skip to EOL (keep newline)
                    i += 2
                    while i < chars.count && chars[i] != "\n" { i += 1 }
                    continue
                }
                if n == "*" {                               // block comment → skip to closing */
                    i += 2
                    while i + 1 < chars.count && !(chars[i] == "*" && chars[i + 1] == "/") { i += 1 }
                    i += 2
                    continue
                }
            }

            if dropTrailingCommas, c == ",", let closer = closerIndex(chars, from: i + 1) {
                i = closer                                  // drop the comma and the gap after it
                continue
            }

            out.append(c); i += 1
        }
        return out
    }

    /// Index of the `}` or `]` that follows `index` across nothing but whitespace and comments —
    /// which is what makes the comma before it a trailing comma. `nil` when anything else is next.
    private static func closerIndex(_ chars: [Character], from index: Int) -> Int? {
        var i = index
        while i < chars.count {
            let c = chars[i]
            if c.isWhitespace { i += 1; continue }
            if c == "/", i + 1 < chars.count, chars[i + 1] == "/" {
                i += 2
                while i < chars.count && chars[i] != "\n" { i += 1 }
                continue
            }
            if c == "/", i + 1 < chars.count, chars[i + 1] == "*" {
                i += 2
                while i + 1 < chars.count && !(chars[i] == "*" && chars[i + 1] == "/") { i += 1 }
                i += 2
                continue
            }
            return (c == "}" || c == "]") ? i : nil
        }
        return nil
    }
}

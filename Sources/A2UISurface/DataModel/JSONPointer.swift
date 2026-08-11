import StructuredDataCore
import A2UICore

/// RFC 6901 JSON Pointer over `StructuredValue`.
///
/// Handles absolute paths that begin with `"/"` (`/user/name`, `/items/0`), including the escape
/// sequences `~1` → `/` and `~0` → `~`. A `~` not followed by `0` or `1` is left alone rather than
/// rejected, so a malformed pointer resolves against the literal text instead of failing.
public enum JSONPointer {

    /// Resolves a path against a base scope, honoring A2UI's relative-path extension.
    ///
    /// A2UI extends RFC 6901 (`renderer_guide.md` §3): a path that does *not* start with `/` is
    /// **relative** and resolves against `scope` (for example `/users/0`), while a path that starts
    /// with `/` is **absolute** and ignores `scope` entirely. This is what lets a component inside
    /// a template instance address its own row.
    ///
    /// - Parameters:
    ///   - path: An absolute path (`/a/b`) or a relative one (`a/b`).
    ///   - scope: The base path for relative resolution; `""` is the document root.
    ///   - data: The document root.
    public static func resolve(path: String, scope: String, in data: StructuredValue) -> StructuredValue? {
        resolve(path: absolutePath(path, scope: scope), in: data)
    }

    /// Combines a relative path with a scope into an absolute one; a path that already starts with
    /// `/` is returned unchanged.
    ///
    /// Both `""` and `"."` address the scope element *itself*, matching the official web_core
    /// `resolvePath`. That is how an element of a scalar array is bound inside a template, where
    /// there is no key to name.
    public static func absolutePath(_ path: String, scope: String) -> String {
        if path.hasPrefix("/") { return path }
        let normalizedScope = scope == "/" ? "" : scope
        if path.isEmpty || path == "." { return normalizedScope.isEmpty ? "/" : normalizedScope }
        let base = normalizedScope.hasSuffix("/") ? String(normalizedScope.dropLast()) : normalizedScope
        return "\(base)/\(path)"
    }

    /// Resolves a JSON Pointer path inside a `StructuredValue`.
    ///
    /// Returns `nil` for an absent path, an out-of-range or non-numeric array index, and a scalar
    /// node in the middle of the path. The result cannot tell those apart, so a caller that needs
    /// to distinguish "missing" from "malformed pointer" has to check the path itself.
    public static func resolve(path: String, in data: StructuredValue) -> StructuredValue? {
        let tokens = parseTokens(path)
        var current = data

        for token in tokens {
            switch current {
            case .object(let dict):
                guard let next = dict[token] else { return nil }
                current = next
            case .array(let arr):
                guard let index = Int(token), index >= 0, index < arr.count else { return nil }
                current = arr[index]
            default:
                return nil
            }
        }

        return current
    }

    /// Writes a value at a JSON Pointer path, creating any missing intermediate containers.
    ///
    /// An empty path replaces the whole document. Writing past the end of an array pads it with
    /// `.null` entries so the index becomes addressable; writing a non-numeric segment into an
    /// existing array discards the array and replaces it with an object.
    public static func set(path: String, value: StructuredValue, in data: inout StructuredValue) {
        let tokens = parseTokens(path)
        guard !tokens.isEmpty else {
            data = value
            return
        }

        setRecursive(tokens: tokens[...], value: value, in: &data)
    }

    /// Removes the node at a JSON Pointer path; a path that does not exist is a no-op.
    ///
    /// Only object keys are removed. A pointer whose parent is an array leaves the array untouched
    /// and reports nothing, so an element cannot be deleted this way.
    public static func remove(path: String, in data: inout StructuredValue) {
        let tokens = parseTokens(path)
        guard !tokens.isEmpty else { return }

        if tokens.count == 1 {
            if case .object(var dict) = data {
                dict.removeValue(forKey: tokens[0])
                data = .object(dict)
            }
            return
        }

        let parentTokens = Array(tokens.dropLast())
        let lastToken = tokens.last!

        guard var parent = resolve(path: "/" + parentTokens.joined(separator: "/"), in: data) else { return }
        if case .object(var dict) = parent {
            dict.removeValue(forKey: lastToken)
            parent = .object(dict)
            set(path: "/" + parentTokens.joined(separator: "/"), value: parent, in: &data)
        }
    }

    // MARK: - Private

    private static func parseTokens(_ path: String) -> [String] {
        guard path.hasPrefix("/") else {
            if path.isEmpty { return [] }
            return path.split(separator: "/", omittingEmptySubsequences: true)
                .map { unescape(String($0)) }
        }

        let withoutLeadingSlash = String(path.dropFirst())
        if withoutLeadingSlash.isEmpty { return [] }

        return withoutLeadingSlash.split(separator: "/", omittingEmptySubsequences: false)
            .map { unescape(String($0)) }
    }

    /// RFC 6901 unescaping: ~1 → /, ~0 → ~
    /// Order matters: unescape ~1 before ~0 to avoid double-processing.
    private static func unescape(_ token: String) -> String {
        // Replace ~1 → / first, then ~0 → ~
        var result = ""
        result.reserveCapacity(token.utf8.count)
        var index = token.startIndex
        while index < token.endIndex {
            let c = token[index]
            if c == "~" {
                let next = token.index(after: index)
                if next < token.endIndex {
                    if token[next] == "1" {
                        result.append("/")
                        index = token.index(after: next)
                        continue
                    } else if token[next] == "0" {
                        result.append("~")
                        index = token.index(after: next)
                        continue
                    }
                }
            }
            result.append(c)
            index = token.index(after: index)
        }
        return result
    }

    private static func setRecursive(tokens: ArraySlice<String>, value: StructuredValue, in data: inout StructuredValue) {
        guard let first = tokens.first else {
            data = value
            return
        }

        let remaining = tokens.dropFirst()
        // Auto-vivification (renderer_guide.md §3): a numeric token implies an Array container,
        // a non-numeric token implies an Object container.
        let firstIsIndex = isArrayIndex(first)

        if remaining.isEmpty {
            // Leaf assignment.
            if firstIsIndex, let index = Int(first) {
                var arr: [StructuredValue] = {
                    if case .array(let existing) = data { return existing }
                    return []
                }()
                growArray(&arr, toInclude: index)
                arr[index] = value
                data = .array(arr)
            } else {
                var dict: OrderedObject = {
                    if case .object(let existing) = data { return existing }
                    return [:]
                }()
                dict[first] = value
                data = .object(dict)
            }
        } else {
            // Intermediate: decide the child container type from the NEXT token.
            let nextIsIndex = isArrayIndex(remaining.first!)
            let emptyChild: StructuredValue = nextIsIndex ? .array([]) : .object([:])

            if firstIsIndex, let index = Int(first) {
                var arr: [StructuredValue] = {
                    if case .array(let existing) = data { return existing }
                    return []
                }()
                growArray(&arr, toInclude: index)
                var child = arr[index]
                if case .null = child { child = emptyChild }
                setRecursive(tokens: remaining, value: value, in: &child)
                arr[index] = child
                data = .array(arr)
            } else {
                var dict: OrderedObject = {
                    if case .object(let existing) = data { return existing }
                    return [:]
                }()
                var child = dict[first] ?? emptyChild
                setRecursive(tokens: remaining, value: value, in: &child)
                dict[first] = child
                data = .object(dict)
            }
        }
    }

    /// A token is an array index if it is a non-negative integer with no leading zeros (except "0").
    private static func isArrayIndex(_ token: String) -> Bool {
        guard let n = Int(token), n >= 0 else { return false }
        return String(n) == token
    }

    /// Grow an array with `.null` (sparse) entries so that `index` is addressable.
    private static func growArray(_ arr: inout [StructuredValue], toInclude index: Int) {
        if index >= arr.count {
            arr.append(contentsOf: Array(repeating: .null, count: index - arr.count + 1))
        }
    }
}

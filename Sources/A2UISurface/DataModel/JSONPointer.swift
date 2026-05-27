import A2UICore

/// RFC 6901 JSON Pointer implementation for AnyCodable.
///
/// Supports absolute paths starting with "/", e.g. "/user/name" or "/items/0".
/// Escaping sequences are handled: ~1 → / and ~0 → ~.
public enum JSONPointer {

    /// Resolve a JSON Pointer path in an AnyCodable value.
    /// Returns nil if the path doesn't exist or any intermediate node is the wrong type.
    public static func resolve(path: String, in data: AnyCodable) -> AnyCodable? {
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

    /// Set a value at a JSON Pointer path, creating intermediate objects as needed.
    public static func set(path: String, value: AnyCodable, in data: inout AnyCodable) {
        let tokens = parseTokens(path)
        guard !tokens.isEmpty else {
            data = value
            return
        }

        setRecursive(tokens: tokens[...], value: value, in: &data)
    }

    /// Remove the node at the given JSON Pointer path.
    /// No-op if the path doesn't exist.
    public static func remove(path: String, in data: inout AnyCodable) {
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

    private static func setRecursive(tokens: ArraySlice<String>, value: AnyCodable, in data: inout AnyCodable) {
        guard let first = tokens.first else {
            data = value
            return
        }

        let remaining = tokens.dropFirst()

        if remaining.isEmpty {
            if case .object(var dict) = data {
                dict[first] = value
                data = .object(dict)
            } else if let index = Int(first), case .array(var arr) = data, index >= 0, index < arr.count {
                arr[index] = value
                data = .array(arr)
            } else {
                data = .object([first: value])
            }
        } else {
            if case .object(var dict) = data {
                var child = dict[first] ?? .object([:])
                setRecursive(tokens: remaining, value: value, in: &child)
                dict[first] = child
                data = .object(dict)
            } else {
                var child: AnyCodable = .object([:])
                setRecursive(tokens: remaining, value: value, in: &child)
                data = .object([first: child])
            }
        }
    }
}

import A2UICore

/// Typed accessors over a `ResolvedComponent`'s resolved props. Used by the typed projections
/// (`ResolvedText`, `ResolvedButton`, …) and available to consumers writing custom projections.
public extension ResolvedComponent {

    /// String value for `key`, or nil. Resolved bindings arrive as `.string`; other scalar kinds
    /// are coerced to a locale-neutral string representation.
    func string(_ key: String) -> String? {
        switch props[key] {
        case .string(let s): return s
        case .int(let i): return String(i)
        case .double(let d): return d == d.rounded() && abs(d) < 1e15 ? String(Int(d)) : String(d)
        case .bool(let b): return b ? "true" : "false"
        default: return nil
        }
    }

    /// Non-optional string (empty when absent) — for required text-like props during render.
    func text(_ key: String) -> String { string(key) ?? "" }

    func bool(_ key: String) -> Bool {
        switch props[key] {
        case .bool(let b): return b
        case .string(let s): return s.lowercased() == "true"
        case .int(let i): return i != 0
        case .double(let d): return d != 0
        default: return false
        }
    }

    func double(_ key: String) -> Double? {
        switch props[key] {
        case .double(let d): return d
        case .int(let i): return Double(i)
        case .string(let s): return Double(s)
        default: return nil
        }
    }

    /// Integer value for `key`, or nil. Coerces from int / int-valued double / numeric string —
    /// the cross-format conversion many ids (e.g. 18-digit recipe ids carried as strings to
    /// preserve precision) need.
    func int(_ key: String) -> Int? {
        switch props[key] {
        case .int(let i): return i
        case .double(let d):
            // Reject lossy / non-integral doubles. Doubles can faithfully hold integers up to 2^53.
            guard d == d.rounded(), abs(d) < 1e15 else { return nil }
            return Int(d)
        case .string(let s): return Int(s)
        default: return nil
        }
    }

    func stringArray(_ key: String) -> [String] {
        guard case .array(let arr)? = props[key] else { return [] }
        return arr.compactMap { if case .string(let s) = $0 { return s } else { return nil } }
    }

    /// Integer array for `key`. Each element is coerced via the same rules as `int(_:)`.
    /// Empty when the prop is absent or not an array.
    func intArray(_ key: String) -> [Int] {
        guard case .array(let arr)? = props[key] else { return [] }
        return arr.compactMap { element in
            switch element {
            case .int(let i): return i
            case .double(let d):
                guard d == d.rounded(), abs(d) < 1e15 else { return nil }
                return Int(d)
            case .string(let s): return Int(s)
            default: return nil
            }
        }
    }

    /// Whether a prop is present and non-empty (used for placeholder/redacted states).
    func isPresent(_ key: String) -> Bool {
        switch props[key] {
        case .none, .null: return false
        case .string(let s): return !s.isEmpty
        default: return true
        }
    }
}

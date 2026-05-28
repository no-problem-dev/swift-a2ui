import A2UICore
import Foundation

/// A2UI v0.9 Type Coercion Standards.
///
/// Implements the coercion table from `renderer_guide.md` §3 ("Type Coercion Standards"):
///
/// | Input                       | Target  | Result                                              |
/// | --------------------------- | ------- | --------------------------------------------------- |
/// | String ("true"/"false")     | Boolean | true/false (case-insensitive); any other → false    |
/// | Number (non-zero)           | Boolean | true                                                |
/// | Number (0)                  | Boolean | false                                               |
/// | Any                         | String  | locale-neutral string representation                |
/// | null / undefined            | String  | "" (empty string)                                   |
/// | null / undefined            | Number  | 0                                                   |
/// | String (numeric)            | Number  | parsed value, or 0                                  |
public enum TypeCoercion {

    /// Coerce a value (possibly nil = undefined) to a String per the spec.
    /// - null/undefined → ""
    /// - Objects/Arrays → JSON-stringified for cross-client consistency
    /// - Numbers/Booleans → standard string representation
    public static func toString(_ value: AnyCodable?) -> String {
        guard let value else { return "" }
        switch value {
        case .null:
            return ""
        case .bool(let b):
            return b ? "true" : "false"
        case .int(let i):
            return String(i)
        case .double(let d):
            // Locale-neutral. Render integral doubles without a trailing ".0"
            // to match JS/Dart-style output used by other A2UI clients.
            if d == d.rounded() && abs(d) < 1e15 {
                return String(Int(d))
            }
            return String(d)
        case .string(let s):
            return s
        case .array, .object:
            return jsonString(value)
        }
    }

    /// Coerce a value (possibly nil = undefined) to a Bool per the spec.
    public static func toBool(_ value: AnyCodable?) -> Bool {
        guard let value else { return false }
        switch value {
        case .null:
            return false
        case .bool(let b):
            return b
        case .int(let i):
            return i != 0
        case .double(let d):
            return d != 0
        case .string(let s):
            switch s.lowercased() {
            case "true": return true
            case "false": return false
            default: return false
            }
        case .array, .object:
            // Non-empty containers are not specified; treat presence as falsey-by-default
            // (spec only defines String/Number coercion to Bool).
            return false
        }
    }

    /// Coerce a value (possibly nil = undefined) to a Double per the spec.
    /// - null/undefined → 0
    /// - numeric strings → parsed, else 0
    public static func toNumber(_ value: AnyCodable?) -> Double {
        guard let value else { return 0 }
        switch value {
        case .null:
            return 0
        case .bool(let b):
            return b ? 1 : 0
        case .int(let i):
            return Double(i)
        case .double(let d):
            return d
        case .string(let s):
            return Double(s) ?? 0
        case .array, .object:
            return 0
        }
    }

    private static func jsonString(_ value: AnyCodable) -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        guard let data = try? encoder.encode(value),
              let str = String(data: data, encoding: .utf8) else {
            return ""
        }
        return str
    }
}

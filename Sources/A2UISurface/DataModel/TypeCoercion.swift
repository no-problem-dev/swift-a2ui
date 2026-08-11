import JSONParsing
import StructuredDataCore
import A2UICore
import Foundation

/// Converts whatever a binding yields into the type a component asked for, never failing.
///
/// Implements the coercion table of `renderer_guide.md` §3:
///
/// | Input                         | Target   | Result                                              |
/// | ----------------------------- | -------- | --------------------------------------------------- |
/// | String ("true"/"false")       | Boolean  | true/false, case-insensitive; anything else false   |
/// | Number (non-zero)             | Boolean  | true                                                |
/// | Number (0)                    | Boolean  | false                                               |
/// | Any                           | String   | Locale-neutral text                                 |
/// | null / undefined              | String   | "" (empty string)                                   |
/// | null / undefined              | Number   | 0                                                   |
/// | String (numeric)              | Number   | The parsed value, or 0                              |
///
/// Every entry is total: coercion never fails and never throws, so an unusable input arrives at the
/// component as the target type's zero value rather than as an error.
public enum TypeCoercion {

    /// Coerces a value to a String per the spec, where a `nil` argument means undefined.
    ///
    /// - null and undefined both become `""`, so a missing binding renders as empty text rather
    ///   than as the word "null".
    /// - Objects and arrays become JSON text with sorted keys, so every A2UI client produces the
    ///   same string.
    /// - Integral numbers lose the trailing `.0` to match the JS/Dart-style output of the other
    ///   clients, so `4.0` renders as `4`.
    public static func toString(_ value: StructuredValue?) -> String {
        guard let value else { return "" }
        switch value {
        case .null:
            return ""
        case .bool(let b):
            return b ? "true" : "false"
        case .number(let n):
            // Locale-neutral. Render integral numbers without a trailing ".0"
            // to match JS/Dart-style output used by other A2UI clients.
            let d = n.double
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

    /// Coerces a value to a Bool per the spec, where a `nil` argument means undefined.
    ///
    /// Only the string `"true"` — in any case — is true. Every other string is false, so `"yes"`
    /// and `"1"` are false, and so are arrays and objects however full they are: the spec defines
    /// Boolean coercion only for String and Number.
    public static func toBool(_ value: StructuredValue?) -> Bool {
        guard let value else { return false }
        switch value {
        case .null:
            return false
        case .bool(let b):
            return b
        case .number(let n):
            return (n.double) != 0
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

    /// Coerces a value to a Double per the spec, where a `nil` argument means undefined.
    ///
    /// null and undefined become 0, and a string that does not parse also becomes 0 — a malformed
    /// number is indistinguishable from a literal `"0"` in the result. Arrays and objects likewise
    /// come back as 0, so a caller that must reject bad input has to inspect the value first.
    public static func toNumber(_ value: StructuredValue?) -> Double {
        guard let value else { return 0 }
        switch value {
        case .null:
            return 0
        case .bool(let b):
            return b ? 1 : 0
        case .number(let n):
            return n.double
        case .string(let s):
            return Double(s) ?? 0
        case .array, .object:
            return 0
        }
    }

    private static func jsonString(_ value: StructuredValue) -> String {
        return JSONSerializer(options: .init(sortKeys: true)).string(from: value)
    }
}

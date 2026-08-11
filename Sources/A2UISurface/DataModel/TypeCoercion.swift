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
            if let i = exactInteger(d) {
                return String(i)
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
    ///
    /// The result is always finite. JSON has no way to write NaN or ±Infinity, so a value that
    /// means one of them is malformed input by definition — but `Double("nan")`, `Double("inf")`
    /// and `Double("1e400")` all parse, and an agent writing the data model puts such strings there
    /// like any other. Letting one through would hand every downstream caller a number that
    /// arithmetic quietly poisons and `Int(_:)` traps on.
    public static func toNumber(_ value: StructuredValue?) -> Double {
        guard let value else { return 0 }
        switch value {
        case .null:
            return 0
        case .bool(let b):
            return b ? 1 : 0
        case .number(let n):
            return finite(n.double)
        case .string(let s):
            return finite(Double(s) ?? 0)
        case .array, .object:
            return 0
        }
    }

    /// Coerces a value to an `Int`, or `nil` when it has none.
    ///
    /// Runs `toNumber` and truncates toward zero, exactly as `Int(_: Double)` does — except that a
    /// magnitude past `Int`'s range answers `nil` instead of trapping. Callers read `nil` the way
    /// they read a missing argument.
    public static func toInt(_ value: StructuredValue?) -> Int? {
        integer(truncating: toNumber(value))
    }

    /// The `Int` a `Double` truncates to, or `nil` when it has none.
    ///
    /// **The only place in the package that converts a `Double` to an `Int`.** `Int(_: Double)`
    /// traps — on NaN, on ±infinity, and on any magnitude past `Int`'s range — so no number that
    /// reached us from the data model may be handed to it. An LLM agent writes that data model,
    /// which makes such numbers ordinary input rather than an edge case.
    public static func integer(truncating d: Double) -> Int? {
        // Non-finite input fails `Int(exactly:)` after truncation, so it needs no separate guard.
        Int(exactly: d.rounded(.towardZero))
    }

    /// The `Int` that stands in for `d` without loss, or `nil` when none does.
    ///
    /// Both the storage decision (`.int` vs `.double`) and the text rendering ask this same
    /// question, so they ask it in one place. Past `1e15` a `Double` no longer carries every
    /// integer, so the substitution stops being faithful there even though it still fits.
    public static func exactInteger(_ d: Double) -> Int? {
        guard abs(d) < 1e15, d == d.rounded() else { return nil }
        return integer(truncating: d)
    }

    /// Replaces NaN and ±infinity with `0`, the same value every other unusable input coerces to.
    private static func finite(_ d: Double) -> Double {
        d.isFinite ? d : 0
    }

    private static func jsonString(_ value: StructuredValue) -> String {
        return JSONSerializer(options: .init(sortKeys: true)).string(from: value)
    }
}

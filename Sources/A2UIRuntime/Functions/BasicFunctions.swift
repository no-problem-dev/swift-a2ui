import A2UICore
import A2UISurface
import Foundation

/// The Basic Catalog function registry (spec §7 + basic_catalog_implementation_guide §2).
///
/// Conforms to `FunctionResolving` so it can be injected into `DataContext`. Each function
/// resolves its (possibly dynamic) arguments through the context, then runs pure logic.
public struct BasicFunctions: FunctionResolving {

    /// Locale used by locale-sensitive functions (formatNumber/Currency, pluralize).
    public let locale: Locale

    public init(locale: Locale = Locale(identifier: "en_US")) {
        self.locale = locale
    }

    public func evaluate(_ call: FunctionCall, in context: DataContext) -> AnyCodable? {
        let args = call.args ?? [:]
        func argString(_ key: String) -> String { ArgResolver.string(args[key], in: context, functions: self) }
        func argNumber(_ key: String) -> Double { ArgResolver.number(args[key], in: context, functions: self) }
        func argResolved(_ key: String) -> AnyCodable? {
            guard let v = args[key] else { return nil }
            return ArgResolver.resolve(v, in: context, functions: self)
        }

        switch call.call {
        case "formatString":
            // value is a string template; resolve to its literal template first (it may itself be a binding).
            let template = argString("value")
            return .string(FormatStringEngine.evaluate(template, in: context, functions: self))

        case "required":
            return .bool(isPresent(argResolved("value")))

        case "regex":
            let value = argString("value")
            let pattern = patternString(args["pattern"])
            return .bool(matches(value, pattern: pattern))

        case "email":
            let value = argString("value")
            return .bool(matches(value, pattern: #"^[^\s@]+@[^\s@]+\.[^\s@]+$"#))

        case "length":
            let len = argString("value").count
            let minOK = args["min"] == nil || len >= Int(argNumber("min"))
            let maxOK = args["max"] == nil || len <= Int(argNumber("max"))
            return .bool(minOK && maxOK)

        case "numeric":
            guard let n = parseNumber(argResolved("value")) else { return .bool(false) }
            let minOK = args["min"] == nil || n >= argNumber("min")
            let maxOK = args["max"] == nil || n <= argNumber("max")
            return .bool(minOK && maxOK)

        case "formatNumber":
            let n = argNumber("value")
            let decimals = args["decimals"].map { _ in Int(argNumber("decimals")) }
            let grouping = args["grouping"].map { _ in ArgResolver.bool(args["grouping"], in: context, functions: self) } ?? true
            return .string(formatNumber(n, decimals: decimals, grouping: grouping))

        case "formatCurrency":
            let n = argNumber("value")
            let currency = argString("currency")
            return .string(formatCurrency(n, currency: currency))

        case "formatDate":
            let value = argResolved("value")
            let format = argString("format")
            return .string(formatDate(value, pattern: format))

        case "pluralize":
            let n = argNumber("value")
            return .string(pluralize(n, args: args, context: context))

        case "and":
            let values = boolList(args["values"], in: context)
            return .bool(values.allSatisfy { $0 })

        case "or":
            let values = boolList(args["values"], in: context)
            return .bool(values.contains(true))

        case "not":
            return .bool(!ArgResolver.bool(args["value"], in: context, functions: self))

        case "openUrl":
            // Side-effect function; returns void. Resolution yields nil.
            return nil

        default:
            return nil
        }
    }

    // MARK: - Logic helpers

    private func isPresent(_ value: AnyCodable?) -> Bool {
        guard let value else { return false }
        switch value {
        case .null: return false
        case .string(let s): return !s.isEmpty
        case .array(let a): return !a.isEmpty
        default: return true
        }
    }

    private func patternString(_ value: AnyCodable?) -> String {
        if case .string(let s)? = value { return s }
        return ""
    }

    private func matches(_ value: String, pattern: String) -> Bool {
        guard !pattern.isEmpty else { return false }
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return false }
        let range = NSRange(value.startIndex..<value.endIndex, in: value)
        return regex.firstMatch(in: value, range: range) != nil
    }

    private func parseNumber(_ value: AnyCodable?) -> Double? {
        switch value {
        case .int(let i): return Double(i)
        case .double(let d): return d
        case .string(let s): return Double(s)
        default: return nil
        }
    }

    private func boolList(_ value: AnyCodable?, in context: DataContext) -> [Bool] {
        guard let resolved = value.flatMap({ ArgResolver.resolve($0, in: context, functions: self) }),
              case .array(let arr) = resolved else { return [] }
        return arr.map { TypeCoercion.toBool($0) }
    }

    private func formatNumber(_ n: Double, decimals: Int?, grouping: Bool) -> String {
        let f = NumberFormatter()
        f.locale = locale
        f.numberStyle = .decimal
        f.usesGroupingSeparator = grouping
        if let decimals {
            f.minimumFractionDigits = decimals
            f.maximumFractionDigits = decimals
        }
        return f.string(from: NSNumber(value: n)) ?? String(n)
    }

    private func formatCurrency(_ n: Double, currency: String) -> String {
        let f = NumberFormatter()
        f.locale = locale
        f.numberStyle = .currency
        if !currency.isEmpty { f.currencyCode = currency }
        return f.string(from: NSNumber(value: n)) ?? String(n)
    }

    private func formatDate(_ value: AnyCodable?, pattern: String) -> String {
        let date: Date?
        switch value {
        case .string(let s):
            date = ISO8601DateFormatter().date(from: s) ?? flexibleParse(s)
        case .double(let d):
            date = Date(timeIntervalSince1970: d)
        case .int(let i):
            date = Date(timeIntervalSince1970: Double(i))
        default:
            date = nil
        }
        guard let date else { return "" }
        let f = DateFormatter()
        f.locale = locale
        // Format in UTC so a UTC input timestamp yields a deterministic, locale-neutral result
        // (matches the spec example: "2026-02-02T15:17:00Z" + "yyyy-MM-dd" → "2026-02-02").
        f.timeZone = TimeZone(identifier: "UTC")
        f.dateFormat = pattern.isEmpty ? "yyyy-MM-dd" : pattern
        return f.string(from: date)
    }

    private func flexibleParse(_ s: String) -> Date? {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f.date(from: s)
    }

    private func pluralize(_ n: Double, args: [String: AnyCodable], context: DataContext) -> String {
        let category = pluralCategory(for: n)
        if let s = args[category], case .string(let str)? = Optional(ArgResolver.resolve(s, in: context, functions: self)) {
            return str
        }
        // Fallback to "other"
        if let other = args["other"] {
            return TypeCoercion.toString(ArgResolver.resolve(other, in: context, functions: self))
        }
        return ""
    }

    /// CLDR plural category. Implements English rules + a generic fallback.
    /// (Full CLDR per-locale rules can be layered in later; English covers the Basic examples.)
    private func pluralCategory(for n: Double) -> String {
        if locale.identifier.hasPrefix("en") {
            return n == 1 ? "one" : "other"
        }
        // Generic: many locales (e.g. ja) have only "other".
        return "other"
    }
}

import A2UICore
import A2UISurface
import Foundation

/// `formatString` 関数の補間エンジン（仕様 §`formatString`）。
///
/// テンプレート文字列内の `${expression}` ブロックをスキャンし、リテラル部分と
/// 埋め込み式の解決値を連結する。仕様 §9.7 の通り、補間はここでのみ行う —
/// 全文字列に対してグローバルには適用しない。
///
/// `${...}` 内の式文法:
/// - データパス: `${/absolute/path}` または `${relative/path}`
/// - 関数呼び出し: `${now()}`、`${formatDate(value:${/d}, format:'yyyy-MM-dd')}`
/// - リテラル（関数引数として）: クォート文字列、数値、true/false/null
/// - エスケープマーカー: `\${` → リテラルの `${`
enum FormatStringEngine {

    static func evaluate(
        _ template: String,
        in context: DataContext,
        functions: any FunctionResolving
    ) -> String {
        var result = ""
        let chars = Array(template)
        var i = 0
        while i < chars.count {
            let c = chars[i]
            // Escaped literal: \${ → ${
            if c == "\\", i + 2 < chars.count, chars[i + 1] == "$", chars[i + 2] == "{" {
                result.append("${")
                i += 3
                continue
            }
            if c == "$", i + 1 < chars.count, chars[i + 1] == "{" {
                // Find the matching closing brace (balanced).
                if let end = matchingBrace(chars, openAt: i + 1) {
                    let exprChars = chars[(i + 2)..<end]
                    let expr = String(exprChars).trimmingCharacters(in: .whitespaces)
                    result += TypeCoercion.toString(evaluateExpression(expr, in: context, functions: functions))
                    i = end + 1
                    continue
                }
            }
            result.append(c)
            i += 1
        }
        return result
    }

    /// 単一の式（パスまたは関数呼び出し）を具体値に評価する。
    static func evaluateExpression(
        _ expr: String,
        in context: DataContext,
        functions: any FunctionResolving
    ) -> StructuredValue? {
        // Function call: identifier followed by (...)
        if let parenIndex = expr.firstIndex(of: "("), expr.hasSuffix(")") {
            let name = String(expr[expr.startIndex..<parenIndex]).trimmingCharacters(in: .whitespaces)
            let argsString = String(expr[expr.index(after: parenIndex)..<expr.index(before: expr.endIndex)])
            let args = parseArgs(argsString, in: context, functions: functions)
            let call = FunctionCall(call: name, args: args.isEmpty ? nil : args, returnType: nil)
            return functions.evaluate(call, in: context)
        }
        // Nested interpolation already-stripped literal (quoted)
        if let literal = parseLiteral(expr) {
            return literal
        }
        // Data path (absolute or relative)
        return context.dataModel.get(expr, scope: context.path)
    }

    // MARK: - Argument parsing

    /// `name: value, name2: value2` 形式を辞書にパースし、各値を解決する。
    private static func parseArgs(
        _ s: String,
        in context: DataContext,
        functions: any FunctionResolving
    ) -> [String: StructuredValue] {
        var out: [String: StructuredValue] = [:]
        for segment in splitTopLevel(s, by: ",") {
            guard let colon = topLevelColon(segment) else { continue }
            let name = String(segment[segment.startIndex..<colon]).trimmingCharacters(in: .whitespaces)
            let rawValue = String(segment[segment.index(after: colon)...]).trimmingCharacters(in: .whitespaces)
            out[name] = evaluateArgValue(rawValue, in: context, functions: functions) ?? .null
        }
        return out
    }

    private static func evaluateArgValue(
        _ raw: String,
        in context: DataContext,
        functions: any FunctionResolving
    ) -> StructuredValue? {
        // Nested explicit binding: ${...}
        if raw.hasPrefix("${"), raw.hasSuffix("}") {
            let inner = String(raw.dropFirst(2).dropLast())
            return evaluateExpression(inner.trimmingCharacters(in: .whitespaces), in: context, functions: functions)
        }
        if let literal = parseLiteral(raw) {
            return literal
        }
        // Bare function call or data path
        return evaluateExpression(raw, in: context, functions: functions)
    }

    private static func parseLiteral(_ s: String) -> StructuredValue? {
        if (s.hasPrefix("'") && s.hasSuffix("'")) || (s.hasPrefix("\"") && s.hasSuffix("\"")), s.count >= 2 {
            return .string(String(s.dropFirst().dropLast()))
        }
        if s == "true" { return .bool(true) }
        if s == "false" { return .bool(false) }
        if s == "null" { return .null }
        if let i = Int(s) { return .int(i) }
        if let d = Double(s) { return .double(d) }
        return nil
    }

    // MARK: - Balanced scanning helpers

    private static func matchingBrace(_ chars: [Character], openAt braceIndex: Int) -> Int? {
        // chars[braceIndex] == "{". Return index of matching "}".
        var depth = 0
        var i = braceIndex
        while i < chars.count {
            if chars[i] == "{" { depth += 1 }
            else if chars[i] == "}" {
                depth -= 1
                if depth == 0 { return i }
            }
            i += 1
        }
        return nil
    }

    /// 文字列をセパレータで分割する。()、{}、クォート内のセパレータは無視する。
    private static func splitTopLevel(_ s: String, by sep: Character) -> [String] {
        var parts: [String] = []
        var current = ""
        var depth = 0
        var quote: Character?
        for c in s {
            if let q = quote {
                current.append(c)
                if c == q { quote = nil }
                continue
            }
            switch c {
            case "'", "\"": quote = c; current.append(c)
            case "(", "{": depth += 1; current.append(c)
            case ")", "}": depth -= 1; current.append(c)
            case sep where depth == 0:
                parts.append(current); current = ""
            default:
                current.append(c)
            }
        }
        if !current.trimmingCharacters(in: .whitespaces).isEmpty { parts.append(current) }
        return parts
    }

    private static func topLevelColon(_ s: String) -> String.Index? {
        var depth = 0
        var quote: Character?
        var idx = s.startIndex
        while idx < s.endIndex {
            let c = s[idx]
            if let q = quote {
                if c == q { quote = nil }
            } else {
                switch c {
                case "'", "\"": quote = c
                case "(", "{": depth += 1
                case ")", "}": depth -= 1
                case ":" where depth == 0: return idx
                default: break
                }
            }
            idx = s.index(after: idx)
        }
        return nil
    }
}

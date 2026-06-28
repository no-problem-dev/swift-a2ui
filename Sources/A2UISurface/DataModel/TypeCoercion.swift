import A2UICore
import Foundation

/// A2UI v0.9 型強制変換の実装。
///
/// `renderer_guide.md` §3 の型強制変換テーブルを実装する:
///
/// | 入力                          | 対象型   | 結果                                                |
/// | ----------------------------- | -------- | --------------------------------------------------- |
/// | String（"true"/"false"）      | Boolean  | true/false（大文字小文字を区別しない）、その他 → false |
/// | Number（非ゼロ）              | Boolean  | true                                                |
/// | Number（0）                   | Boolean  | false                                               |
/// | Any                           | String   | ロケール非依存の文字列表現                          |
/// | null / undefined              | String   | ""（空文字列）                                      |
/// | null / undefined              | Number   | 0                                                   |
/// | String（数値文字列）          | Number   | パース値、または 0                                  |
public enum TypeCoercion {

    /// 値（nil = undefined を含む）を仕様に従って String に強制変換する。
    /// - null/undefined → ""
    /// - オブジェクト/配列 → クライアント間の一貫性のため JSON 文字列化
    /// - Number/Boolean → 標準的な文字列表現
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

    /// 値（nil = undefined を含む）を仕様に従って Bool に強制変換する。
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

    /// 値（nil = undefined を含む）を仕様に従って Double に強制変換する。
    /// - null/undefined → 0
    /// - 数値文字列 → パース値、パース不可なら 0
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

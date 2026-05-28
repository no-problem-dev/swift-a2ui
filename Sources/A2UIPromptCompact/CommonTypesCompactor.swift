import A2UICore
import Foundation

/// `common_types.json` から FunctionCall 関連の `$defs` を物理的に剥がすユーティリティ。
///
/// **非公式最適化**: A2UI v0.9 spec は catalog に `functions` を持たない構成を明示禁止していないが、
/// 推奨もしていない。catalog 側で `functions: []` を採用しているアプリ専用の最適化として、
/// LLM に「function 形式は使えない」と確信させるため `FunctionCall` / `DynamicValue` の型定義と、
/// 各 Dynamic* 型の `oneOf` 内の FunctionCall 分岐を取り除く。
///
/// 結果として:
/// - `FunctionCall`, `DynamicValue` の `$def` が消える
/// - `DynamicString`, `DynamicNumber`, `DynamicBoolean`, `DynamicStringList` の `oneOf` から
///   FunctionCall への参照を含む allOf 要素が消える
/// - 続けて `SchemaPruner.pruneCommonTypes` で芋づる式に到達不能な定義が削れる
public enum CommonTypesCompactor {

    /// FunctionCall サポートを取り除いた common_types を返す。
    /// 入力が parse できない場合は元の文字列をそのまま返す（安全側）。
    public static func compact(_ commonTypesJSON: String) -> String {
        guard let data = commonTypesJSON.data(using: .utf8),
              let value = try? JSONDecoder().decode(AnyCodable.self, from: data),
              case .object(var root) = value else {
            return commonTypesJSON
        }

        // 1. $defs から FunctionCall / DynamicValue を削除
        if case .object(var defs)? = root["$defs"] {
            defs.removeValue(forKey: "FunctionCall")
            defs.removeValue(forKey: "DynamicValue")

            // 2. 各 $defs の oneOf 内から FunctionCall 参照を含む要素を除去
            for key in defs.keys {
                if let updated = stripFunctionCallReferences(in: defs[key]!) {
                    defs[key] = updated
                }
            }
            root["$defs"] = .object(defs)
        }

        return serialize(.object(root)) ?? commonTypesJSON
    }

    /// AnyCodable 値の中から FunctionCall への参照を持つ allOf / $ref 要素を再帰的に除去する。
    private static func stripFunctionCallReferences(in value: AnyCodable) -> AnyCodable? {
        switch value {
        case .object(var dict):
            // "oneOf": [...] の中身を走査して FunctionCall 参照を含む要素を除去
            if case .array(let arr)? = dict["oneOf"] {
                let filtered = arr.filter { !containsFunctionCallReference($0) }
                if filtered.isEmpty {
                    dict.removeValue(forKey: "oneOf")
                } else {
                    dict["oneOf"] = .array(filtered)
                }
            }
            // 入れ子の dict 内も再帰
            for (key, child) in dict {
                if let updated = stripFunctionCallReferences(in: child) {
                    dict[key] = updated
                }
            }
            return .object(dict)

        case .array(let arr):
            return .array(arr.compactMap { stripFunctionCallReferences(in: $0) ?? $0 })

        default:
            return nil
        }
    }

    /// 与えられた値が FunctionCall への `$ref` を直接 / `allOf` 内に含むかを判定。
    private static func containsFunctionCallReference(_ value: AnyCodable) -> Bool {
        switch value {
        case .object(let dict):
            if case .string(let ref)? = dict["$ref"], isFunctionCallRef(ref) {
                return true
            }
            if case .array(let inner)? = dict["allOf"] {
                return inner.contains(where: containsFunctionCallReference)
            }
            return false
        default:
            return false
        }
    }

    private static func isFunctionCallRef(_ ref: String) -> Bool {
        ref == "#/$defs/FunctionCall" || ref.hasSuffix("common_types.json#/$defs/FunctionCall")
    }

    private static func serialize(_ value: AnyCodable) -> String? {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        guard let data = try? encoder.encode(value),
              let string = String(data: data, encoding: .utf8) else {
            return nil
        }
        return string
    }
}

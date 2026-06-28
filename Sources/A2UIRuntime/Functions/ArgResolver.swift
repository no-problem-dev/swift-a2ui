import A2UICore
import A2UISurface
import Foundation

/// 関数呼び出しの引数（生の `StructuredValue`）を具体値に解決するリゾルバ。
/// 埋め込まれたデータバインド（`{"path": "..."}`）やネストした関数呼び出し（`{"call": "..."}`）を解釈する。
///
/// `renderer_guide.md` §2 の通り、コンテキスト層は関数の純粋ロジックが実行される前に
/// 動的な引数を解決する。引数自体が `Dynamic*` 値になりうるため、解決は再帰的に行う。
enum ArgResolver {

    /// 指定のコンテキストに対して引数値を解決する。
    /// - 平スカラー / 配列 / オブジェクトはそのまま通過（ネストしたバインドは再帰解決）。
    /// - `{"path": "..."}` はデータモデルの値に解決する。
    /// - `{"call": "..."}` はネストした関数を評価する。
    static func resolve(_ value: StructuredValue, in context: DataContext, functions: any FunctionResolving) -> StructuredValue? {
        switch value {
        case .object(let dict):
            if case .string(let path)? = dict["path"], dict.count == 1 {
                return context.dataModel.get(path, scope: context.path)
            }
            if case .string? = dict["call"] {
                if let call = try? decodeFunctionCall(dict) {
                    return functions.evaluate(call, in: context)
                }
                return nil
            }
            // Plain object: resolve each value recursively.
            var out = OrderedObject()
            for (k, v) in dict {
                out[k] = resolve(v, in: context, functions: functions) ?? .null
            }
            return .object(out)
        case .array(let arr):
            return .array(arr.map { resolve($0, in: context, functions: functions) ?? .null })
        default:
            return value
        }
    }

    /// 引数を解決して String に変換する。
    static func string(_ value: StructuredValue?, in context: DataContext, functions: any FunctionResolving) -> String {
        guard let value else { return "" }
        return TypeCoercion.toString(resolve(value, in: context, functions: functions))
    }

    /// 引数を解決して Double に変換する。
    static func number(_ value: StructuredValue?, in context: DataContext, functions: any FunctionResolving) -> Double {
        guard let value else { return 0 }
        return TypeCoercion.toNumber(resolve(value, in: context, functions: functions))
    }

    /// 引数を解決して Bool に変換する。
    static func bool(_ value: StructuredValue?, in context: DataContext, functions: any FunctionResolving) -> Bool {
        guard let value else { return false }
        return TypeCoercion.toBool(resolve(value, in: context, functions: functions))
    }

    private static func decodeFunctionCall(_ dict: OrderedObject) throws -> FunctionCall {
        return try StructuredValue.object(dict).decode(FunctionCall.self)
    }
}

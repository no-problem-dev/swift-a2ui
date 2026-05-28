import A2UICore
import A2UISurface
import Foundation

/// Resolves a function-call argument (raw `AnyCodable`) into a concrete value, interpreting any
/// embedded data bindings (`{"path": "..."}`) or nested function calls (`{"call": "..."}`).
///
/// Per `renderer_guide.md` §2, the Context layer resolves dynamic arguments before a function's
/// pure logic runs. Arguments may themselves be `Dynamic*` values, so resolution is recursive.
enum ArgResolver {

    /// Resolve an argument value against the given context.
    /// - Plain scalars/arrays/objects pass through (with nested bindings resolved).
    /// - `{"path": "..."}` resolves to the bound data-model value.
    /// - `{"call": "..."}` evaluates the nested function.
    static func resolve(_ value: AnyCodable, in context: DataContext, functions: any FunctionResolving) -> AnyCodable? {
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
            var out: [String: AnyCodable] = [:]
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

    /// Resolve and coerce an argument to String.
    static func string(_ value: AnyCodable?, in context: DataContext, functions: any FunctionResolving) -> String {
        guard let value else { return "" }
        return TypeCoercion.toString(resolve(value, in: context, functions: functions))
    }

    /// Resolve and coerce an argument to Double.
    static func number(_ value: AnyCodable?, in context: DataContext, functions: any FunctionResolving) -> Double {
        guard let value else { return 0 }
        return TypeCoercion.toNumber(resolve(value, in: context, functions: functions))
    }

    /// Resolve and coerce an argument to Bool.
    static func bool(_ value: AnyCodable?, in context: DataContext, functions: any FunctionResolving) -> Bool {
        guard let value else { return false }
        return TypeCoercion.toBool(resolve(value, in: context, functions: functions))
    }

    private static func decodeFunctionCall(_ dict: [String: AnyCodable]) throws -> FunctionCall {
        let data = try JSONEncoder().encode(AnyCodable.object(dict))
        return try JSONDecoder().decode(FunctionCall.self, from: data)
    }
}

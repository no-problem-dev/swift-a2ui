import StructuredDataCore
import A2UICore
import A2UISurface
import Foundation

/// Resolves the raw `StructuredValue` arguments of a function call down to concrete values.
///
/// It interprets embedded data bindings (`{"path": "..."}`) and nested calls (`{"call": "..."}`). Per
/// `renderer_guide.md` §2 the context layer resolves dynamic arguments before a function's pure logic
/// runs; because an argument can itself be a `Dynamic*` value, resolution recurses.
enum ArgResolver {

    /// Resolves one argument value against the given context.
    ///
    /// - A plain scalar, array, or object passes through, with nested bindings resolved recursively.
    /// - `{"path": "..."}` resolves to the data-model value, but only when `path` is the object's sole
    ///   key; an object that carries anything else alongside it is treated as plain data.
    /// - `{"call": "..."}` evaluates the nested function.
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

    /// Resolves an argument and coerces it to `String`; a missing argument yields `""`, which the
    /// function cannot tell apart from a binding that resolved to nothing.
    static func string(_ value: StructuredValue?, in context: DataContext, functions: any FunctionResolving) -> String {
        guard let value else { return "" }
        return TypeCoercion.toString(resolve(value, in: context, functions: functions))
    }

    /// Resolves an argument and coerces it to `Double`; a missing argument and an unparseable one both
    /// yield `0`, so check for the key first where the difference matters.
    static func number(_ value: StructuredValue?, in context: DataContext, functions: any FunctionResolving) -> Double {
        guard let value else { return 0 }
        return TypeCoercion.toNumber(resolve(value, in: context, functions: functions))
    }

    /// Resolves an argument and coerces it to `Bool`; a missing argument yields `false`, and so does any
    /// array or object (the spec defines coercion only from string and number).
    static func bool(_ value: StructuredValue?, in context: DataContext, functions: any FunctionResolving) -> Bool {
        guard let value else { return false }
        return TypeCoercion.toBool(resolve(value, in: context, functions: functions))
    }

    private static func decodeFunctionCall(_ dict: OrderedObject) throws -> FunctionCall {
        return try StructuredValue.object(dict).decode(FunctionCall.self)
    }
}

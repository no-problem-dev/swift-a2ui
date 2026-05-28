import A2UICore
import A2UISurface

/// A transient, scoped window into a `DataModel`, used during rendering to resolve data bindings.
///
/// Implements the Context Layer from `renderer_guide.md` §3. A `DataContext` carries the current
/// **evaluation scope** (a JSON Pointer path). Relative bindings (`name`) resolve against the scope;
/// absolute bindings (`/company`) resolve from the root. Template iteration creates child scopes
/// via `nested(_:)`.
public struct DataContext: Sendable {
    public let dataModel: DataModel
    /// The current scope path (e.g. `/employees/0`). Empty string means root scope.
    public let path: String
    private let functions: any FunctionResolving

    public init(dataModel: DataModel, path: String = "", functions: any FunctionResolving = NoFunctionResolver()) {
        self.dataModel = dataModel
        self.path = path
        self.functions = functions
    }

    /// Create a child context scoped to `relativePath` resolved against the current scope.
    /// Used by template list rendering: each item gets `nested("/items/<index>")` (absolute index path).
    public func nested(_ relativePath: String) -> DataContext {
        let childPath = JSONPointer.absolutePath(relativePath, scope: path)
        return DataContext(dataModel: dataModel, path: childPath, functions: functions)
    }

    // MARK: - Resolution (snapshot)

    /// Resolve a `DynamicValue` to its current concrete value (or nil = undefined).
    public func resolve(_ value: DynamicValue) -> AnyCodable? {
        switch value {
        case .string(let s): return .string(s)
        case .number(let n): return numberValue(n)
        case .boolean(let b): return .bool(b)
        case .array(let arr): return .array(arr)
        case .binding(let b): return dataModel.get(b.path, scope: path)
        case .functionCall(let call): return functions.evaluate(call, in: self)
        }
    }

    /// Resolve a `DynamicString` to a String, applying A2UI type coercion (nil → "").
    public func resolveString(_ value: DynamicString) -> String {
        switch value {
        case .literal(let s): return s
        case .binding(let b): return TypeCoercion.toString(dataModel.get(b.path, scope: path))
        case .functionCall(let call): return TypeCoercion.toString(functions.evaluate(call, in: self))
        }
    }

    /// Resolve a `DynamicBoolean` to a Bool, applying A2UI type coercion (nil → false).
    public func resolveBool(_ value: DynamicBoolean) -> Bool {
        switch value {
        case .literal(let b): return b
        case .binding(let b): return TypeCoercion.toBool(dataModel.get(b.path, scope: path))
        case .functionCall(let call): return TypeCoercion.toBool(functions.evaluate(call, in: self))
        }
    }

    /// Resolve a `DynamicNumber` to a Double, applying A2UI type coercion (nil → 0).
    public func resolveNumber(_ value: DynamicNumber) -> Double {
        switch value {
        case .literal(let n): return n
        case .binding(let b): return TypeCoercion.toNumber(dataModel.get(b.path, scope: path))
        case .functionCall(let call): return TypeCoercion.toNumber(functions.evaluate(call, in: self))
        }
    }

    // MARK: - Subscription (reactive)

    /// Subscribe to a `DynamicValue`. For bindings this tracks the underlying path reactively
    /// (initial value fires synchronously). For literals/functions it fires once with the value.
    @discardableResult
    public func subscribe(
        _ value: DynamicValue,
        _ onChange: @escaping (AnyCodable?) -> Void
    ) -> A2UISubscription {
        switch value {
        case .binding(let b):
            return dataModel.subscribe(b.path, scope: path, onChange)
        default:
            onChange(resolve(value))
            return .inert
        }
    }

    /// Subscribe to a `DynamicString`, delivering coerced String values.
    @discardableResult
    public func subscribeString(
        _ value: DynamicString,
        _ onChange: @escaping (String) -> Void
    ) -> A2UISubscription {
        switch value {
        case .binding(let b):
            return dataModel.subscribe(b.path, scope: path) { onChange(TypeCoercion.toString($0)) }
        default:
            onChange(resolveString(value))
            return .inert
        }
    }

    // MARK: - Write

    /// Write a value at a (possibly relative) path within this scope. Used by two-way bindings.
    public func set(_ relativeOrAbsolutePath: String, _ value: AnyCodable?) {
        dataModel.set(relativeOrAbsolutePath, value, scope: path)
    }

    private func numberValue(_ n: Double) -> AnyCodable {
        if n == n.rounded() && abs(n) < 1e15 { return .int(Int(n)) }
        return .double(n)
    }
}

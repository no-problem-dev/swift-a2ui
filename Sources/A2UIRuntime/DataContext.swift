import StructuredDataCore
import A2UICore
import A2UISurface

/// A transient, scoped view onto a `DataModel` for resolving data bindings while rendering.
///
/// Implements the context layer of `renderer_guide.md` §3. The context carries the current **evaluation
/// scope** as a JSON Pointer path: a relative binding (`name`) resolves from that scope, an absolute one
/// (`/company`) from the root. Template iteration produces child scopes through `nested(_:)`.
public struct DataContext: Sendable {
    public let dataModel: DataModel
    /// The current scope path, such as `/employees/0`; the empty string is the root scope.
    public let path: String
    /// Zero-based index of the template iteration (collection scope); `nil` outside an iteration.
    ///
    /// Spec v1.0: the built-in `@index` evaluates **only while a template is being instantiated**, and
    /// calling it anywhere else is an evaluation error. This value is what says whether we are inside an
    /// iteration.
    public let collectionIndex: Int?
    private let functions: any FunctionResolving

    public init(
        dataModel: DataModel,
        path: String = "",
        collectionIndex: Int? = nil,
        functions: any FunctionResolving = NoFunctionResolver()
    ) {
        self.dataModel = dataModel
        self.path = path
        self.collectionIndex = collectionIndex
        self.functions = functions
    }

    /// Resolves `relativePath` against the current scope and returns a child context scoped there.
    ///
    /// Used when rendering a template list: each item receives `nested("/items/<index>")`, the absolute
    /// indexed path, so relative bindings inside the template land on that element.
    ///
    /// - Parameter collectionIndex: The zero-based index when entering as a template iteration. Omit it
    ///   and the child is an ordinary scope rather than an iteration, which turns `@index` inside it into
    ///   an evaluation error.
    public func nested(_ relativePath: String, collectionIndex: Int? = nil) -> DataContext {
        let childPath = JSONPointer.absolutePath(relativePath, scope: path)
        return DataContext(
            dataModel: dataModel,
            path: childPath,
            collectionIndex: collectionIndex,
            functions: functions
        )
    }

    // MARK: - Resolution (snapshot)

    /// Resolves a `DynamicValue` to its value at this instant; `nil` when it is undefined.
    ///
    /// A snapshot: it does not track later writes. Use `subscribe(_:_:)` where the view has to keep up
    /// with the data model.
    public func resolve(_ value: DynamicValue) -> StructuredValue? {
        switch value {
        case .string(let s): return .string(s)
        case .number(let n): return numberValue(n)
        case .boolean(let b): return .bool(b)
        case .array(let arr): return .array(arr)
        case .binding(let b): return dataModel.get(b.path, scope: path)
        case .functionCall(let call): return functions.evaluate(call, in: self)
        }
    }

    /// Resolves a `DynamicString`, applying A2UI coercion: an undefined binding becomes `""`.
    ///
    /// An empty label can therefore mean a wrong path rather than empty text; nothing is raised.
    public func resolveString(_ value: DynamicString) -> String {
        switch value {
        case .literal(let s): return s
        case .binding(let b): return TypeCoercion.toString(dataModel.get(b.path, scope: path))
        case .functionCall(let call): return TypeCoercion.toString(functions.evaluate(call, in: self))
        }
    }

    /// Resolves a `DynamicBoolean`, applying A2UI coercion: an undefined binding becomes `false`.
    ///
    /// A `checks` condition on a path that has not arrived yet therefore reads as a failing check.
    public func resolveBool(_ value: DynamicBoolean) -> Bool {
        switch value {
        case .literal(let b): return b
        case .binding(let b): return TypeCoercion.toBool(dataModel.get(b.path, scope: path))
        case .functionCall(let call): return TypeCoercion.toBool(functions.evaluate(call, in: self))
        }
    }

    /// Resolves a `DynamicNumber`, applying A2UI coercion: an undefined binding becomes `0`.
    ///
    /// A slider or progress value bound to a missing path lands at `0` rather than reporting anything.
    public func resolveNumber(_ value: DynamicNumber) -> Double {
        switch value {
        case .literal(let n): return n
        case .binding(let b): return TypeCoercion.toNumber(dataModel.get(b.path, scope: path))
        case .functionCall(let call): return TypeCoercion.toNumber(functions.evaluate(call, in: self))
        }
    }

    // MARK: - Subscription (reactive)

    /// Subscribes to a `DynamicValue`, tracking a bound path and delivering the current value
    /// synchronously before returning.
    ///
    /// Literals and function calls fire once and hand back `.inert`: a function result is not
    /// re-evaluated when the data its arguments read changes.
    @discardableResult
    public func subscribe(
        _ value: DynamicValue,
        _ onChange: @escaping (StructuredValue?) -> Void
    ) -> A2UISubscription {
        switch value {
        case .binding(let b):
            return dataModel.subscribe(b.path, scope: path, onChange)
        default:
            onChange(resolve(value))
            return .inert
        }
    }

    /// Subscribes to a `DynamicString` and delivers already-coerced values, so the callback never sees
    /// `nil` and a deleted path arrives as `""`.
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

    /// Writes a value at a path — relative to this scope, or absolute — the way two-way bindings do when
    /// the user edits a field.
    public func set(_ relativeOrAbsolutePath: String, _ value: StructuredValue?) {
        dataModel.set(relativeOrAbsolutePath, value, scope: path)
    }

    private func numberValue(_ n: Double) -> StructuredValue {
        if n == n.rounded() && abs(n) < 1e15 { return .int(Int(n)) }
        return .double(n)
    }
}

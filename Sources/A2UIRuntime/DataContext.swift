import A2UICore
import A2UISurface

/// レンダリング中にデータバインドを解決するための、`DataModel` への一時的なスコープ付きビュー。
///
/// `renderer_guide.md` §3 のコンテキスト層を実装する。`DataContext` は現在の**評価スコープ**
/// （JSON Pointer パス）を保持する。相対バインド（`name`）はスコープを起点に解決し、
/// 絶対バインド（`/company`）はルートから解決する。テンプレートの反復は `nested(_:)` で
/// 子スコープを生成する。
public struct DataContext: Sendable {
    public let dataModel: DataModel
    /// 現在のスコープパス（例: `/employees/0`）。空文字列はルートスコープを意味する。
    public let path: String
    private let functions: any FunctionResolving

    public init(dataModel: DataModel, path: String = "", functions: any FunctionResolving = NoFunctionResolver()) {
        self.dataModel = dataModel
        self.path = path
        self.functions = functions
    }

    /// 現在のスコープに対して `relativePath` を解決し、その位置にスコープを持つ子コンテキストを生成する。
    /// テンプレートリストのレンダリングで使用。各アイテムは `nested("/items/<index>")` (絶対インデックスパス) を受け取る。
    public func nested(_ relativePath: String) -> DataContext {
        let childPath = JSONPointer.absolutePath(relativePath, scope: path)
        return DataContext(dataModel: dataModel, path: childPath, functions: functions)
    }

    // MARK: - Resolution (snapshot)

    /// `DynamicValue` を現在の具体値に解決する。未定義の場合は nil。
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

    /// `DynamicString` を String に解決する。A2UI 型変換を適用（nil → ""）。
    public func resolveString(_ value: DynamicString) -> String {
        switch value {
        case .literal(let s): return s
        case .binding(let b): return TypeCoercion.toString(dataModel.get(b.path, scope: path))
        case .functionCall(let call): return TypeCoercion.toString(functions.evaluate(call, in: self))
        }
    }

    /// `DynamicBoolean` を Bool に解決する。A2UI 型変換を適用（nil → false）。
    public func resolveBool(_ value: DynamicBoolean) -> Bool {
        switch value {
        case .literal(let b): return b
        case .binding(let b): return TypeCoercion.toBool(dataModel.get(b.path, scope: path))
        case .functionCall(let call): return TypeCoercion.toBool(functions.evaluate(call, in: self))
        }
    }

    /// `DynamicNumber` を Double に解決する。A2UI 型変換を適用（nil → 0）。
    public func resolveNumber(_ value: DynamicNumber) -> Double {
        switch value {
        case .literal(let n): return n
        case .binding(let b): return TypeCoercion.toNumber(dataModel.get(b.path, scope: path))
        case .functionCall(let call): return TypeCoercion.toNumber(functions.evaluate(call, in: self))
        }
    }

    // MARK: - Subscription (reactive)

    /// `DynamicValue` を購読する。バインドの場合は対象パスをリアクティブに追跡し（初期値は同期発火）、
    /// リテラル / 関数は値を一度だけ発火する。
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

    /// `DynamicString` を購読し、変換済みの String 値を届ける。
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

    /// このスコープ内の（相対または絶対）パスに値を書き込む。双方向バインドで使用。
    public func set(_ relativeOrAbsolutePath: String, _ value: StructuredValue?) {
        dataModel.set(relativeOrAbsolutePath, value, scope: path)
    }

    private func numberValue(_ n: Double) -> StructuredValue {
        if n == n.rounded() && abs(n) < 1e15 { return .int(Int(n)) }
        return .double(n)
    }
}

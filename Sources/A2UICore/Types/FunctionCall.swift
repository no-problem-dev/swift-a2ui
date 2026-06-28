/// 関数の呼び出し元制約（A2UI v0.10 `callableFrom`）。
public enum CallableFrom: String, Codable, Sendable, Equatable {
    case clientOnly
    case remoteOnly
    case clientOrRemote
}

/// クライアント側関数またはサーバ起動関数の呼び出し仕様。
///
/// `call` は関数名、`args` は文字列キーの引数マップ。`callableFrom` を省略した場合は
/// `clientOnly` とみなす。
public struct FunctionCall: Codable, Sendable, Equatable {
    public let call: String
    public let args: [String: StructuredValue]?
    public let returnType: FunctionReturnType?
    /// v0.10: この関数を実行できる場所。省略時は `clientOnly`。
    public let callableFrom: CallableFrom?

    public init(
        call: String,
        args: [String: StructuredValue]? = nil,
        returnType: FunctionReturnType? = nil,
        callableFrom: CallableFrom? = nil
    ) {
        self.call = call
        self.args = args
        self.returnType = returnType
        self.callableFrom = callableFrom
    }
}

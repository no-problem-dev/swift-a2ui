/// Where a function may be invoked from (A2UI v0.10 `callableFrom`).
public enum CallableFrom: String, Codable, Sendable, Equatable {
    case clientOnly
    case remoteOnly
    case clientOrRemote
}

public struct FunctionCall: Codable, Sendable, Equatable {
    public let call: String
    public let args: [String: StructuredValue]?
    public let returnType: FunctionReturnType?
    /// v0.10: where this function may run. Defaults to `clientOnly` when omitted.
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

public struct FunctionCall: Codable, Sendable, Equatable {
    public let call: String
    public let args: [String: StructuredValue]?
    public let returnType: FunctionReturnType?

    public init(call: String, args: [String: StructuredValue]? = nil, returnType: FunctionReturnType? = nil) {
        self.call = call
        self.args = args
        self.returnType = returnType
    }
}

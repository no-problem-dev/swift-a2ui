public struct FunctionCall: Codable, Sendable, Equatable {
    public let call: String
    public let args: [String: AnyCodable]?
    public let returnType: FunctionReturnType?

    public init(call: String, args: [String: AnyCodable]? = nil, returnType: FunctionReturnType? = nil) {
        self.call = call
        self.args = args
        self.returnType = returnType
    }
}

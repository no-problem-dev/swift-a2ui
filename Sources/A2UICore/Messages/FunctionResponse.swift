/// Client→server result of a server-initiated function call (A2UI v0.10).
///
/// `functionCallId` and `call` are copied verbatim from the originating `CallFunctionMessage`.
public struct FunctionResponse: Codable, Sendable, Equatable {
    public let functionCallId: CallId
    public let call: String
    public let value: StructuredValue

    public init(functionCallId: CallId, call: String, value: StructuredValue) {
        self.functionCallId = functionCallId
        self.call = call
        self.value = value
    }
}

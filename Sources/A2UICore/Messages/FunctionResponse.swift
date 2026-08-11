import StructuredDataCore
/// The result the client sends back after running a function the agent asked for (A2UI v1.0).
///
/// Copy `functionCallId` and `call` verbatim from the originating `CallFunctionMessage`: the agent
/// correlates on them and has no other way to tell two calls in flight apart. Send `error` instead
/// when the call could not run at all.
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

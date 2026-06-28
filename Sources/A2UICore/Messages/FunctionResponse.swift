/// クライアント → サーバのサーバ起動関数呼び出し結果（A2UI v0.10）。
///
/// `functionCallId` と `call` は発信元の `CallFunctionMessage` からそのまま複写する。
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

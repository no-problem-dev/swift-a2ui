public struct EventAction: Codable, Sendable, Equatable {
    public let name: String
    public let context: [String: DynamicValue]?
    /// v0.10: if true, the client expects an `actionResponse` from the server.
    public let wantResponse: Bool?
    /// v0.10: optional JSON Pointer where the client saves the response value in its local data model.
    public let responsePath: String?

    public init(
        name: String,
        context: [String: DynamicValue]? = nil,
        wantResponse: Bool? = nil,
        responsePath: String? = nil
    ) {
        self.name = name
        self.context = context
        self.wantResponse = wantResponse
        self.responsePath = responsePath
    }
}

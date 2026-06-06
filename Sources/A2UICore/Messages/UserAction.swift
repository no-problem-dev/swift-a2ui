public struct UserAction: Codable, Sendable, Equatable {
    public let name: String
    public let surfaceId: String
    public let sourceComponentId: String
    public let timestamp: String  // ISO 8601
    public let context: [String: StructuredValue]
    /// v0.10: if true, the client expects an `actionResponse` from the server.
    public let wantResponse: Bool?
    /// v0.10: unique ID for this action call. Only needed when `wantResponse` is true.
    public let actionId: String?

    public init(
        name: String,
        surfaceId: String,
        sourceComponentId: String,
        timestamp: String,
        context: [String: StructuredValue],
        wantResponse: Bool? = nil,
        actionId: String? = nil
    ) {
        self.name = name
        self.surfaceId = surfaceId
        self.sourceComponentId = sourceComponentId
        self.timestamp = timestamp
        self.context = context
        self.wantResponse = wantResponse
        self.actionId = actionId
    }
}

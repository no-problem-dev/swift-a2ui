public struct UserAction: Codable, Sendable, Equatable {
    public let name: String
    public let surfaceId: String
    public let sourceComponentId: String
    public let timestamp: String  // ISO 8601
    public let context: [String: StructuredValue]

    public init(
        name: String,
        surfaceId: String,
        sourceComponentId: String,
        timestamp: String,
        context: [String: StructuredValue]
    ) {
        self.name = name
        self.surfaceId = surfaceId
        self.sourceComponentId = sourceComponentId
        self.timestamp = timestamp
        self.context = context
    }
}

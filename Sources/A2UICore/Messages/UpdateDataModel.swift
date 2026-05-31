public struct UpdateDataModel: Codable, Sendable, Equatable {
    public let surfaceId: String
    public let path: String?
    public let value: StructuredValue?

    public init(
        surfaceId: String,
        path: String? = nil,
        value: StructuredValue? = nil
    ) {
        self.surfaceId = surfaceId
        self.path = path
        self.value = value
    }
}

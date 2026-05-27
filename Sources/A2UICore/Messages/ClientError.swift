public struct ClientError: Codable, Sendable, Equatable {
    public let code: String
    public let surfaceId: String
    public let message: String
    public let path: String?

    public init(
        code: String,
        surfaceId: String,
        message: String,
        path: String? = nil
    ) {
        self.code = code
        self.surfaceId = surfaceId
        self.message = message
        self.path = path
    }
}

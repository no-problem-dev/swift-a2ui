public struct DeleteSurface: Codable, Sendable, Equatable {
    public let surfaceId: String

    public init(surfaceId: String) {
        self.surfaceId = surfaceId
    }
}

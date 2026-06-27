/// Instructs the client to tear down and discard the named surface entirely.
public struct DeleteSurface: Codable, Sendable, Equatable {
    public let surfaceId: String

    public init(surfaceId: String) {
        self.surfaceId = surfaceId
    }
}

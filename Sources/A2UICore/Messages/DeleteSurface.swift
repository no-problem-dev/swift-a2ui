/// Tells the client to tear a surface down, discarding its components and its data model
/// (A2UI v1.0).
///
/// Sending this is also how a `surfaceId` becomes available again: `CreateSurface` may not reuse
/// the id of a surface that is still alive.
public struct DeleteSurface: Codable, Sendable, Equatable {
    public let surfaceId: String

    public init(surfaceId: String) {
        self.surfaceId = surfaceId
    }
}

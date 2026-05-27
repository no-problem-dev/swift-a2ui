// components stored as [AnyCodable] to be catalog-agnostic; typed decode happens in A2UICatalog
public struct UpdateComponents: Codable, Sendable, Equatable {
    public let surfaceId: String
    public let components: [AnyCodable]

    public init(surfaceId: String, components: [AnyCodable]) {
        self.surfaceId = surfaceId
        self.components = components
    }
}

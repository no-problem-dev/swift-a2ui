// components stored as [StructuredValue] to be catalog-agnostic; typed decode happens in A2UICatalog
public struct UpdateComponents: Codable, Sendable, Equatable {
    public let surfaceId: String
    public let components: [StructuredValue]

    public init(surfaceId: String, components: [StructuredValue]) {
        self.surfaceId = surfaceId
        self.components = components
    }
}

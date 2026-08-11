import StructuredDataCore
/// Inserts components into a surface, replacing any that already carry the same `id` (A2UI v1.0).
///
/// Components stay as `StructuredValue` so this type is catalog-agnostic; turning them into
/// concrete component types is `A2UICatalog`'s job, and an unknown component name therefore fails
/// there rather than here.
public struct UpdateComponents: Codable, Sendable, Equatable {
    public let surfaceId: String
    public let components: [StructuredValue]

    public init(surfaceId: String, components: [StructuredValue]) {
        self.surfaceId = surfaceId
        self.components = components
    }
}

/// Names one component instance within a surface: containers list their children by it, and an
/// `UpdateComponents` replaces the component that already holds it.
///
/// Uniqueness only holds inside a surface, so an id is never a key across surfaces.
public typealias ComponentId = String

/// What every A2UI component type has to provide, whichever catalog defines it.
///
/// `componentName` is the discriminator on the wire (`"Button"`, for example) and is what decoding
/// dispatches on; `id` identifies the instance inside its surface and scopes both updates and data
/// bindings.
public protocol A2UIComponentProtocol: Codable, Sendable, Equatable {
    static var componentName: String { get }
    var id: ComponentId { get }
    var accessibility: AccessibilityAttributes? { get }
    var weight: Double? { get }
    /// Catalog this component is resolved in (`ComponentCommon.catalogId`), overriding the surface
    /// default from `CreateSurface.catalogId` — this is what lets one surface mix catalogs.
    var catalogId: String? { get }
}

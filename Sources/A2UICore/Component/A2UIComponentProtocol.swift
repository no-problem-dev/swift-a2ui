/// Stable string key that identifies a component instance on a surface (JSON Pointer root).
public typealias ComponentId = String

/// Base protocol every A2UI component struct conforms to.
///
/// `componentName` is the wire discriminator (e.g. `"Button"`); `id` is the surface-local
/// identity used for updates and data-binding scoping.
public protocol A2UIComponentProtocol: Codable, Sendable, Equatable {
    static var componentName: String { get }
    var id: ComponentId { get }
    var accessibility: AccessibilityAttributes? { get }
    var weight: Double? { get }
}

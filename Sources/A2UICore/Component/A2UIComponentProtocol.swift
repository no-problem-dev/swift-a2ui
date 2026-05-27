public typealias ComponentId = String

public protocol A2UIComponentProtocol: Codable, Sendable, Equatable {
    static var componentName: String { get }
    var id: ComponentId { get }
    var accessibility: AccessibilityAttributes? { get }
    var weight: Double? { get }
}

import A2UICore

/// A node in a resolved component tree.
public struct ComponentNode: Sendable, Equatable {
    /// The component's unique identifier.
    public let id: String
    /// The raw component data.
    public let component: StructuredValue
    /// Resolved child nodes.
    public var children: [ComponentNode]

    public init(id: String, component: StructuredValue, children: [ComponentNode] = []) {
        self.id = id
        self.component = component
        self.children = children
    }
}

import StructuredDataCore
import A2UICore

/// One node of a resolved component tree.
public struct ComponentNode: Sendable, Equatable {
    /// The component's key in the flat component dictionary; the root node's id is `"root"`.
    public let id: String
    /// The component's raw JSON, left unresolved — its child fields still hold ids, not nodes.
    public let component: StructuredValue
    /// Resolved children, in the order the parent's child fields declare them. A child id that is
    /// absent from the component dictionary is skipped silently, so this can be shorter than the
    /// list of ids in `component`.
    public var children: [ComponentNode]

    public init(id: String, component: StructuredValue, children: [ComponentNode] = []) {
        self.id = id
        self.component = component
        self.children = children
    }
}

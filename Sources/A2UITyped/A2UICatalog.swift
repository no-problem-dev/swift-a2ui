import A2UICore
import A2UICatalog

/// The **catalog** a consumer injects, fixing at compile time which components a renderer can draw.
///
/// A2UI's extension model is that the client owns a catalog of components it trusts and the agent may
/// request only what is in it. The library ships `BasicCatalog`; an application combines that with its own
/// design-system components through `CombinedNode`, as in
/// `enum AppCatalog: A2UICatalog { typealias Node = CombinedNode<MyNode, BasicComponent>; ... }`.
///
/// A renderer takes this protocol as a type parameter (`A2UIRenderer<some A2UICatalog>`), so dispatch
/// stays exhaustive at compile time while remaining open to extension by the consumer.
public protocol A2UICatalog: Sendable {
    /// The closed sum type of components this catalog renders; any `component` name outside it decodes
    /// as `CatalogNode.unknown`.
    associatedtype Node: ComponentNode

    /// The canonical identifier URI, matching the `catalogId` that components and function calls name on
    /// the wire.
    static var catalogId: String { get }

    /// The functions this catalog registers, which is what makes the spec's permission boundary
    /// checkable at run time: `callableFrom` never travels with a `callFunction`, so the renderer has
    /// to look the name up here rather than trust the message.
    ///
    /// The default is empty, and an unregistered name is refused — a catalog that declares no
    /// functions therefore refuses every agent-initiated call, which is the safe reading and the one
    /// the spec asks for.
    static var functions: [FunctionSchema] { get }
}

extension A2UICatalog {
    public static var functions: [FunctionSchema] { [] }
}

/// Composes two node types, routing each `component` name to whichever one claims it.
///
/// `Primary` wins a name collision, so a consumer can override a basic component with its own
/// implementation. Putting the basic node in `Fallback` is what keeps coverage complete: the consumer
/// embeds the whole basic node rather than re-enumerating its cases.
public enum CombinedNode<Primary: ComponentNode, Fallback: ComponentNode>: ComponentNode {
    case primary(Primary)
    case fallback(Fallback)

    public static var componentNames: Set<String> {
        Primary.componentNames.union(Fallback.componentNames)
    }

    public var id: ComponentId {
        switch self {
        case .primary(let node): return node.id
        case .fallback(let node): return node.id
        }
    }

    public var componentName: String {
        switch self {
        case .primary(let node): return node.componentName
        case .fallback(let node): return node.componentName
        }
    }

    public var catalogId: String? {
        switch self {
        case .primary(let node): return node.catalogId
        case .fallback(let node): return node.catalogId
        }
    }

    private enum Keys: String, CodingKey { case component }

    public init(from decoder: Decoder) throws {
        let name = try decoder.container(keyedBy: Keys.self).decode(String.self, forKey: .component)
        if Primary.componentNames.contains(name) {
            self = .primary(try Primary(from: decoder))
        } else {
            // Fallback owns the rest (and throws if it, too, does not handle the name).
            self = .fallback(try Fallback(from: decoder))
        }
    }
}

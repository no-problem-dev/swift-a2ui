import A2UICore

/// A consumer-injected **catalog**: the compile-time set of components a renderer may draw.
///
/// A2UI's whole extensibility model is "the client owns a catalog of trusted components; the agent
/// may only request what is in it." Here that catalog is a *type* the consumer supplies. The
/// library ships `BasicCatalog`; an application composes it with its own design-system components
/// via `CombinedNode`, e.g. `typealias AppCatalog = Catalog<CombinedNode<MyNode, BasicNode>>`.
///
/// The renderer is generic over this protocol (`A2UIRenderer<some A2UICatalog>`), so dispatch is
/// total and exhaustive at compile time while staying open to consumer extension at the type level.
public protocol A2UICatalog: Sendable {
    /// The closed sum of components this catalog renders.
    associatedtype Node: ComponentNode

    /// The canonical catalog identifier URI (matches the A2UI `catalogId` on the wire).
    static var catalogId: String { get }
}

/// Composes two node types into one, routing each `component` name to the catalog that declares it.
///
/// `Primary` wins on name collisions, so a consumer can shadow/override a basic component with their
/// own implementation. The library keeps ownership (and completeness guarantees) of whichever node
/// it ships — typically `BasicNode` placed as `Fallback` — so "forgot to list Card" is impossible:
/// the consumer embeds the basic node whole rather than re-enumerating its cases.
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

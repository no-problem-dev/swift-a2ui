import A2UICore

/// Wraps a catalog's `Known` node with A2UI's mandated unknown-component handling.
///
/// The spec distinguishes two cases the renderer must treat differently, so they are separated
/// here at the type level instead of collapsing into a stringly-typed `default:` branch:
///
/// - **Catalog miss** (`component` name not in `Known.componentNames`): the agent referenced a
///   component this client does not have. Per the A2UI renderer guide this must degrade gracefully
///   (placeholder / skip, never crash) — represented as a first-class `.unknown` case carrying the
///   name + raw payload so the renderer can show a "Not Supported" fallback and report it.
/// - **Structural failure** (name is known but props are malformed): a genuine validation error.
///   `Known(from:)` is allowed to `throw`, which the decode pipeline surfaces as an error to send
///   back to the agent (the spec's prompt→generate→validate loop).
public enum CatalogNode<Known: ComponentNode>: Decodable, Sendable, Equatable {
    case known(Known)
    case unknown(name: String, id: ComponentId, raw: StructuredValue)

    private enum Keys: String, CodingKey { case component, id }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: Keys.self)
        let name = try container.decode(String.self, forKey: .component)
        if Known.componentNames.contains(name) {
            // Known name → decode strictly. A throw here is a validation error, not an unknown.
            self = .known(try Known(from: decoder))
        } else {
            let id = try container.decodeIfPresent(ComponentId.self, forKey: .id) ?? ""
            self = .unknown(name: name, id: id, raw: try StructuredValue(from: decoder))
        }
    }

    /// The instance id, whichever variant. Unknown components still carry an id on the wire.
    public var id: ComponentId {
        switch self {
        case .known(let node): return node.id
        case .unknown(_, let id, _): return id
        }
    }

    /// The wire `component` discriminator (the unknown name is preserved verbatim).
    public var componentName: String {
        switch self {
        case .known(let node): return node.componentName
        case .unknown(let name, _, _): return name
        }
    }
}

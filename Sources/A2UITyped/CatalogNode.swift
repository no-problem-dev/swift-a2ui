import StructuredDataCore
import A2UICore

/// Wraps a catalog's `Known` node type with the unknown-component handling A2UI mandates.
///
/// It separates, at the type level, the two failures a renderer must treat differently:
///
/// - **Catalog miss** (the `component` name is not in `Known.componentNames`): the agent asked for a
///   component this client does not have. The A2UI renderer guide requires graceful degradation — show a
///   placeholder or skip it, never crash. That case is `.unknown`, which keeps the name and the raw
///   payload so the placeholder can say what was missing.
/// - **Structural failure** (the name is known but its properties are malformed): a genuine validation
///   error. `Known(from:)` is allowed to throw, and the decode pipeline propagates the error back to the
///   agent as feedback (the spec's prompt → generate → validate loop).
public enum CatalogNode<Known: ComponentNode>: Decodable, Sendable, Equatable {
    case known(Known)
    case unknown(name: String, id: ComponentId, raw: StructuredValue)

    private enum Keys: String, CodingKey { case component, id, catalogId }

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

    /// The catalog id this component states for itself (v1.0 `ComponentCommon.catalogId`).
    ///
    /// `nil` when the component omits it, which hands the decision to the surface default `catalogId`.
    /// Read through `resolveCatalog(surfaceDefault:)` rather than acting on this value directly.
    public var declaredCatalogId: String? {
        switch self {
        case .known(let node): return node.catalogId
        case .unknown(_, _, let raw): return raw["catalogId"].stringValue
        }
    }

    /// Decodes leniently: a known name with malformed properties is demoted to `.unknown` instead of
    /// throwing.
    ///
    /// Use this in the live message processor, where one bad component must not stop the whole surface
    /// from rendering; the bad spot stays visible, and diagnosable, as a "Not Supported" marker. Use the
    /// throwing `init(from:)` where a malformed component should become feedback to the agent instead.
    public static func lenientDecode(_ value: StructuredValue) -> CatalogNode<Known> {
        if let node = try? value.decode(CatalogNode<Known>.self) {
            return node
        }
        let probe = try? value.decode(Probe.self)
        return .unknown(name: probe?.component ?? "Unknown", id: probe?.id ?? "", raw: value)
    }

    private struct Probe: Decodable { let component: String?; let id: String? }

    /// The instance id, kept in both cases — an unknown component still carries its id on the wire, so it
    /// stays addressable in the flat id map and by later updates.
    public var id: ComponentId {
        switch self {
        case .known(let node): return node.id
        case .unknown(_, let id, _): return id
        }
    }

    /// The `component` discriminator as it arrived on the wire.
    ///
    /// For `.unknown` it is the agent's name verbatim, so a placeholder can name what was requested.
    public var componentName: String {
        switch self {
        case .known(let node): return node.componentName
        case .unknown(let name, _, _): return name
        }
    }
}

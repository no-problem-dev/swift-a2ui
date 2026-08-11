import StructuredDataCore
import Foundation
import Observation
import A2UICore
import A2UISurface
import A2UITyped

/// A renderable surface bound to one `Catalog`: a flat id-to-node map plus its data model.
///
/// Mirrors the A2UI wire model, where components live in a flat map keyed by id and a parent
/// refers to its children by id string. The live store is `[ComponentId: CatalogNode<Catalog.Node>]`
/// — fully typed, no `any`. Being `@Observable`, it drives SwiftUI through the two kinds of A2UI
/// partial update:
/// - `updateComponents` mutates `nodes`, which is tracked, and redraws the structure.
/// - `updateDataModel` writes into the non-observable `DataModel` and increments `dataVersion`,
///   which is tracked instead. Views that read bindings depend on `dataVersion`, so they
///   re-resolve. The grain is coarse — every binding re-resolves on any write — but correct.
@MainActor
@Observable
public final class TypedSurface<Catalog: A2UICatalog>: Identifiable {
    /// The A2UI `surfaceId`. Defaults to `rootId` when the initializer is given no id, which is
    /// the single-surface case.
    public let id: String
    public let catalogId: String
    public let rootId: ComponentId
    public let dataModel: DataModel
    /// The host's sink for user events such as a `Button`'s `action.event`, called with
    /// `(name, context, sourceComponentId)`. Defaults to a no-op, so events vanish silently
    /// on a surface constructed without one.
    let onEvent: (String, [String: StructuredValue], ComponentId) -> Void

    private var nodes: [ComponentId: CatalogNode<Catalog.Node>]
    /// Incremented on every write to the data model. Views that read bindings depend on it, and
    /// that dependency is the whole of their reactivity.
    private(set) var dataVersion = 0
    /// Incremented once per `updateComponents` batch. `A2UISurfaceView` uses it as an animation
    /// value, which is what makes streamed-in components arrive with a transition instead of
    /// popping into place.
    private(set) var structureVersion = 0

    public init(
        id: String? = nil,
        rootId: ComponentId = "root",
        nodes: [CatalogNode<Catalog.Node>],
        dataModel: DataModel = DataModel(),
        onEvent: @escaping (String, [String: StructuredValue], ComponentId) -> Void = { _, _, _ in }
    ) {
        self.id = id ?? rootId
        self.catalogId = Catalog.catalogId
        self.rootId = rootId
        self.dataModel = dataModel
        self.onEvent = onEvent
        self.nodes = Dictionary(nodes.map { ($0.id, $0) }, uniquingKeysWith: { _, new in new })
    }

    public func node(_ id: ComponentId) -> CatalogNode<Catalog.Node>? { nodes[id] }

    // MARK: - Partial updates (A2UI processing layer)

    /// Applies `updateComponents` by upserting on id.
    ///
    /// As the spec requires, a new node for an existing id replaces it wholesale — including a
    /// change of component type — rather than merging field by field.
    public func applyUpdateComponents(_ incoming: [CatalogNode<Catalog.Node>]) {
        for node in incoming { nodes[node.id] = node }
        structureVersion += 1
    }

    /// Applies `updateDataModel`: writes the value at the JSON Pointer path and triggers
    /// re-resolution. An empty path replaces the whole model root.
    public func applyUpdateDataModel(path: String, value: StructuredValue?) {
        dataModel.set(path, value)
        touchData()
    }

    /// Bumps the data version so views that read bindings re-resolve. Call it after writing to the
    /// data model behind the surface's back, as the two-way input bindings do.
    func touchData() { dataVersion += 1 }

    // MARK: - Decoding

    /// Decodes an A2UI `updateComponents.components` array, whose elements are
    /// `{id, component, …}`, into nodes.
    ///
    /// A component name the catalog does not know degrades to `.unknown` instead of throwing, which
    /// is the graceful handling the spec calls for. Malformed JSON still throws.
    public static func decodeNodes(fromJSONArray data: Data) throws -> [CatalogNode<Catalog.Node>] {
        try JSONDecoder().decode([CatalogNode<Catalog.Node>].self, from: data)
    }
}

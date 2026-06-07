import Foundation
import Observation
import A2UICore
import A2UISurface
import A2UITyped

/// A rendered surface for a specific `Catalog`: the flat id→node map plus the data model.
///
/// Mirrors A2UI's wire model (components are a flat map keyed by id; parents reference children by
/// id string) — so the live store is `[ComponentId: CatalogNode<Catalog.Node>]`, fully typed, no
/// `any`. `@Observable`, so SwiftUI re-renders on the two A2UI partial-update kinds:
/// - `updateComponents` mutates `nodes` (tracked) → structure re-renders.
/// - `updateDataModel` writes the (non-observable) `DataModel` and bumps `dataVersion` (tracked);
///   binding-reading views depend on `dataVersion`, so they re-resolve. (Coarse but correct;
///   per-path subscription is a later optimization.)
@MainActor
@Observable
public final class TypedSurface<Catalog: A2UICatalog>: Identifiable {
    /// Surface identifier (the A2UI `surfaceId`). Defaults to `rootId` for single-surface use.
    public let id: String
    public let catalogId: String
    public let rootId: ComponentId
    public let dataModel: DataModel
    /// Host sink for user-dispatched events (Button `action.event` etc.): `(name, context, sourceComponentId)`.
    /// Default no-op.
    let onEvent: (String, [String: StructuredValue], ComponentId) -> Void

    private var nodes: [ComponentId: CatalogNode<Catalog.Node>]
    /// Bumped on every data-model write; binding readers depend on it for reactivity.
    private(set) var dataVersion = 0
    /// Bumped on every `updateComponents` batch. `A2UISurfaceView` animates on this so
    /// streamed-in components enter with a transition (cascading assembly) instead of popping.
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

    /// Apply `updateComponents`: upsert by id. Per the spec, a new node for an existing id replaces
    /// it wholesale (the id may even change component type), which a dictionary upsert handles.
    public func applyUpdateComponents(_ incoming: [CatalogNode<Catalog.Node>]) {
        for node in incoming { nodes[node.id] = node }
        structureVersion += 1
    }

    /// Apply `updateDataModel`: write a value at a JSON-Pointer path and trigger re-resolution.
    public func applyUpdateDataModel(path: String, value: StructuredValue?) {
        dataModel.set(path, value)
        touchData()
    }

    /// Bump the data version so binding readers re-resolve (used by two-way input writes).
    func touchData() { dataVersion += 1 }

    // MARK: - Decoding

    /// Decode an A2UI `updateComponents.components` array (each `{id, component, ...}`) into nodes.
    /// Unknown component names degrade to `.unknown` rather than throwing (spec graceful handling).
    public static func decodeNodes(fromJSONArray data: Data) throws -> [CatalogNode<Catalog.Node>] {
        try JSONDecoder().decode([CatalogNode<Catalog.Node>].self, from: data)
    }
}

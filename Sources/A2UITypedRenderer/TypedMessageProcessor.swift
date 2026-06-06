import Foundation
import A2UICore
import A2UISurface
import A2UITyped

/// Applies A2UI `ServerMessage`s to a set of typed surfaces — the typed counterpart of
/// `A2UISurface.MessageProcessor`, producing `TypedSurface<Catalog>` instead of `SurfaceModel`.
///
/// A host (e.g. the Studio app) parses the agent's `<a2ui-json>` into `[ServerMessage]` and feeds
/// them here; `surfaces` is then rendered with `A2UISurfaceView`. User actions surface through
/// `onAction` as `UserAction`, matching the old processor so host logic is unchanged.
@MainActor
@Observable
public final class TypedMessageProcessor<Catalog: A2UICatalog> {
    public private(set) var surfaces: [String: TypedSurface<Catalog>] = [:]

    /// Surface ids in the order they were first created. Drives paging/stacking so a newly created
    /// surface (a "new canvas") appends after existing ones instead of jumping by id sort order.
    private var creationOrder: [String] = []

    /// Host sink for user actions (Button events etc.). Mirrors `MessageProcessor.onAction`.
    public var onAction: (UserAction) -> Void

    public init(onAction: @escaping (UserAction) -> Void = { _ in }) {
        self.onAction = onAction
    }

    /// Surfaces in creation order (for `ForEach` / paging). Falls back to id sort for any surface
    /// that predates creation tracking (defensive; normally every surface is recorded on create).
    public var ordered: [TypedSurface<Catalog>] {
        creationOrder.compactMap { surfaces[$0] }
    }

    public func process(_ messages: [ServerMessage]) {
        for message in messages { process(message) }
    }

    public func process(_ message: ServerMessage) {
        switch message {
        case .createSurface(let cs):
            // v0.10: createSurface may carry the initial tree and data model inline.
            // The official eval validator treats these as exactly equivalent to a
            // following updateComponents / root updateDataModel, so they flow through
            // the same apply functions. Data model first: bindings resolve by the
            // time the root component appears.
            let surface = makeSurface(id: cs.surfaceId)
            surfaces[cs.surfaceId] = surface
            record(cs.surfaceId)
            if let dataModel = cs.dataModel {
                surface.applyUpdateDataModel(path: "", value: dataModel)
            }
            if let components = cs.components {
                surface.applyUpdateComponents(components.map { CatalogNode<Catalog.Node>.lenientDecode($0) })
            }
        case .updateComponents(let uc):
            let surface = surfaces[uc.surfaceId] ?? makeSurface(id: uc.surfaceId)
            surfaces[uc.surfaceId] = surface
            record(uc.surfaceId)
            // Lenient: a malformed known component degrades to an `.unknown` placeholder instead of
            // silently disappearing, so partial/invalid LLM output renders a visible marker.
            let nodes = uc.components.map { CatalogNode<Catalog.Node>.lenientDecode($0) }
            surface.applyUpdateComponents(nodes)
        case .updateDataModel(let udm):
            let surface = surfaces[udm.surfaceId] ?? makeSurface(id: udm.surfaceId)
            surfaces[udm.surfaceId] = surface
            record(udm.surfaceId)
            surface.applyUpdateDataModel(path: udm.path ?? "", value: udm.value)
        case .deleteSurface(let ds):
            surfaces.removeValue(forKey: ds.surfaceId)
            creationOrder.removeAll { $0 == ds.surfaceId }
        case .callFunction, .actionResponse:
            // v0.10 server-initiated RPC / action responses are handled by the host, not the
            // surface store (they don't mutate the component tree directly).
            break
        }
    }

    public func removeAll() {
        surfaces.removeAll()
        creationOrder.removeAll()
    }

    /// Append a surface id to the creation order the first time it is seen.
    private func record(_ id: String) {
        if !creationOrder.contains(id) { creationOrder.append(id) }
    }

    private func makeSurface(id: String) -> TypedSurface<Catalog> {
        TypedSurface(id: id, rootId: "root", nodes: []) { [weak self] name, context, sourceComponentId in
            self?.onAction(UserAction(
                name: name,
                surfaceId: id,
                sourceComponentId: sourceComponentId,
                timestamp: ISO8601DateFormatter().string(from: Date()),
                context: context
            ))
        }
    }
}

import Foundation
import A2UICore
import A2UISurface
import A2UITyped

/// Applies A2UI `AgentMessage`s to a set of typed surfaces — the typed counterpart of
/// `A2UISurface.MessageProcessor`, producing `TypedSurface<Catalog>` instead of `SurfaceModel`.
///
/// A host parses the agent's `<a2ui-json>` into `[AgentMessage]` and hands it here; the resulting
/// `surfaces` are what you pass to `A2UISurfaceView`. User interactions come back out as
/// `UserAction` values through `onAction`, so the untyped and typed processors are interchangeable
/// from the host's side.
@MainActor
@Observable
public final class TypedMessageProcessor<Catalog: A2UICatalog> {
    public private(set) var surfaces: [String: TypedSurface<Catalog>] = [:]

    /// Surface ids in creation order, so paging and stacked presentations append a new surface at
    /// the end instead of dropping it wherever id sorting would put it.
    private var creationOrder: [String] = []

    /// The host's sink for user interactions such as a `Button` event; the counterpart of
    /// `MessageProcessor.onAction`. Assign it before processing messages or actions are dropped.
    public var onAction: (UserAction) -> Void

    public init(onAction: @escaping (UserAction) -> Void = { _ in }) {
        self.onAction = onAction
    }

    /// Surfaces in creation order, ready for `ForEach` or a pager. A surface that never made it
    /// into the creation record is omitted here even though it is still present in `surfaces`.
    public var ordered: [TypedSurface<Catalog>] {
        creationOrder.compactMap { surfaces[$0] }
    }

    public func process(_ messages: [AgentMessage]) {
        for message in messages { process(message) }
    }

    public func process(_ message: AgentMessage) {
        switch message {
        case .createSurface(let cs):
            // v1.0: createSurface may carry the initial tree and data model inline.
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
            // v1.0 server-initiated RPC / action responses are handled by the host, not the
            // surface store (they don't mutate the component tree directly).
            break
        }
    }

    public func removeAll() {
        surfaces.removeAll()
        creationOrder.removeAll()
    }

    /// Appends a surface id to the creation-order list the first time it is seen, so a surface that
    /// arrives via `updateComponents` before any `createSurface` still gets an ordering slot.
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

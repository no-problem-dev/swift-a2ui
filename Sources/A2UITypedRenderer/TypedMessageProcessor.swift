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

    /// Host sink for user actions (Button events etc.). Mirrors `MessageProcessor.onAction`.
    public var onAction: (UserAction) -> Void

    public init(onAction: @escaping (UserAction) -> Void = { _ in }) {
        self.onAction = onAction
    }

    /// Surfaces in stable id order (for `ForEach`).
    public var ordered: [TypedSurface<Catalog>] {
        surfaces.values.sorted { $0.id < $1.id }
    }

    public func process(_ messages: [ServerMessage]) {
        for message in messages { process(message) }
    }

    public func process(_ message: ServerMessage) {
        switch message {
        case .createSurface(let cs):
            surfaces[cs.surfaceId] = makeSurface(id: cs.surfaceId)
        case .updateComponents(let uc):
            let surface = surfaces[uc.surfaceId] ?? makeSurface(id: uc.surfaceId)
            surfaces[uc.surfaceId] = surface
            let nodes = uc.components.compactMap { try? $0.decode(CatalogNode<Catalog.Node>.self) }
            surface.applyUpdateComponents(nodes)
        case .updateDataModel(let udm):
            let surface = surfaces[udm.surfaceId] ?? makeSurface(id: udm.surfaceId)
            surfaces[udm.surfaceId] = surface
            surface.applyUpdateDataModel(path: udm.path ?? "", value: udm.value)
        default:
            break
        }
    }

    public func removeAll() { surfaces.removeAll() }

    private func makeSurface(id: String) -> TypedSurface<Catalog> {
        TypedSurface(id: id, rootId: "root", nodes: []) { [weak self] name, context in
            self?.onAction(UserAction(
                name: name,
                surfaceId: id,
                sourceComponentId: "",
                timestamp: ISO8601DateFormatter().string(from: Date()),
                context: context
            ))
        }
    }
}

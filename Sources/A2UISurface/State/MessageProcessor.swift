import A2UICore
import Observation

/// The "Controller" that accepts validated A2UI messages and mutates the reactive state models
/// (spec §3 "Processing Layer").
///
/// Owns the set of active `SurfaceModel`s. Applies lifecycle rules:
/// - `createSurface` for an existing id is an error (spec).
/// - `updateComponents` honors the same-id/different-type recreate rule (delegated to
///   `SurfaceComponentsModel`).
/// - `getClientDataModel()` aggregates data models of surfaces with `sendDataModel == true`.
///
/// `@MainActor` because the underlying `@Observable` models drive SwiftUI.
@MainActor
@Observable
public final class MessageProcessor {

    public enum ProcessError: Error, Equatable {
        case surfaceAlreadyExists(String)
        case surfaceNotFound(String)
    }

    public private(set) var surfaces: [String: SurfaceModel] = [:]

    /// Retains per-surface action subscriptions so they are not cancelled on deinit.
    @ObservationIgnored
    private var actionSubscriptions: [String: A2UISubscription] = [:]

    @ObservationIgnored
    public let onSurfaceCreated = EventSource<SurfaceModel>()
    @ObservationIgnored
    public let onSurfaceDeleted = EventSource<String>()
    @ObservationIgnored
    public let onAction = EventSource<UserAction>()

    public init() {}

    public func surface(id: String) -> SurfaceModel? {
        surfaces[id]
    }

    /// Apply a batch of messages in order.
    @discardableResult
    public func process(_ messages: [ServerMessage]) -> [ProcessError] {
        var errors: [ProcessError] = []
        for message in messages {
            do {
                try process(message)
            } catch let error as ProcessError {
                errors.append(error)
            } catch {
                // ComponentValidator and other errors are non-fatal at the batch level.
            }
        }
        return errors
    }

    public func process(_ message: ServerMessage) throws {
        switch message {
        case .createSurface(let cs):
            guard surfaces[cs.surfaceId] == nil else {
                throw ProcessError.surfaceAlreadyExists(cs.surfaceId)
            }
            let model = SurfaceModel(
                id: cs.surfaceId,
                catalogId: cs.catalogId,
                theme: cs.theme,
                sendDataModel: cs.sendDataModel ?? false
            )
            // Bubble surface-level actions up to the processor's stream.
            // Retain the subscription so it isn't cancelled when the local handle deinits.
            actionSubscriptions[cs.surfaceId] = model.onAction.subscribe { [weak self] action in
                self?.onAction.emit(action)
            }
            surfaces[cs.surfaceId] = model
            onSurfaceCreated.emit(model)

        case .updateComponents(let uc):
            guard let surface = surfaces[uc.surfaceId] else {
                throw ProcessError.surfaceNotFound(uc.surfaceId)
            }
            try ComponentValidator.validateUniqueIds(components: uc.components)
            for component in uc.components {
                surface.components.apply(component)
            }

        case .updateDataModel(let udm):
            guard let surface = surfaces[udm.surfaceId] else {
                throw ProcessError.surfaceNotFound(udm.surfaceId)
            }
            if let path = udm.path, !path.isEmpty, path != "/" {
                surface.dataModel.set(path, udm.value)
            } else if let value = udm.value {
                surface.dataModel.set("", value)
            }

        case .deleteSurface(let ds):
            guard surfaces[ds.surfaceId] != nil else {
                throw ProcessError.surfaceNotFound(ds.surfaceId)
            }
            surfaces.removeValue(forKey: ds.surfaceId)
            actionSubscriptions.removeValue(forKey: ds.surfaceId)?.cancel()
            onSurfaceDeleted.emit(ds.surfaceId)
        }
    }

    /// Remove every surface, cancelling action subscriptions and emitting `onSurfaceDeleted` for
    /// each. Used when the host resets the session (e.g. user starts a fresh conversation).
    public func removeAll() {
        let ids = Array(surfaces.keys)
        surfaces.removeAll()
        for sub in actionSubscriptions.values { sub.cancel() }
        actionSubscriptions.removeAll()
        for id in ids { onSurfaceDeleted.emit(id) }
    }

    /// Aggregate data models of surfaces with `sendDataModel == true`, keyed by surface id.
    /// The host/transport includes this in client→server message metadata (spec §3).
    public func getClientDataModel() -> [String: StructuredValue] {
        var out: [String: StructuredValue] = [:]
        for (id, surface) in surfaces where surface.sendDataModel {
            out[id] = surface.dataModel.snapshot
        }
        return out
    }
}

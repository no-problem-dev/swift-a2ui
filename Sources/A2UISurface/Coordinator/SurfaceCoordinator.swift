import A2UICore

/// Interprets ServerMessages and applies validated mutations to SurfaceStore.
/// All business logic lives here; the Store holds only state.
public struct SurfaceCoordinator: Sendable {

    public enum CoordinatorError: Error, Sendable, Equatable {
        case surfaceAlreadyExists(String)
        case surfaceNotFound(String)
    }

    private let store: SurfaceStore

    public init(store: SurfaceStore) {
        self.store = store
    }

    /// Process a server message, validating inputs and applying mutations to the store.
    public func handle(_ message: ServerMessage) async throws {
        switch message {
        case .createSurface(let cs):
            guard await store.surface(id: cs.surfaceId) == nil else {
                throw CoordinatorError.surfaceAlreadyExists(cs.surfaceId)
            }
            let state = SurfaceState(
                id: cs.surfaceId,
                catalogId: cs.catalogId,
                theme: cs.theme,
                sendDataModel: cs.sendDataModel ?? false
            )
            await store.createSurface(state)

        case .updateComponents(let uc):
            guard await store.surface(id: uc.surfaceId) != nil else {
                throw CoordinatorError.surfaceNotFound(uc.surfaceId)
            }
            try ComponentValidator.validateUniqueIds(components: uc.components)
            var componentMap: [String: AnyCodable] = [:]
            for component in uc.components {
                if case .object(let dict) = component,
                   case .string(let id) = dict["id"] {
                    componentMap[id] = component
                }
            }
            await store.updateComponents(surfaceId: uc.surfaceId, components: componentMap)

        case .updateDataModel(let udm):
            guard await store.surface(id: udm.surfaceId) != nil else {
                throw CoordinatorError.surfaceNotFound(udm.surfaceId)
            }
            await store.updateDataModel(
                surfaceId: udm.surfaceId,
                path: udm.path,
                value: udm.value
            )

        case .deleteSurface(let ds):
            guard await store.surface(id: ds.surfaceId) != nil else {
                throw CoordinatorError.surfaceNotFound(ds.surfaceId)
            }
            await store.deleteSurface(id: ds.surfaceId)
        }
    }

    /// Build a component tree for the given surface.
    /// Throws `CoordinatorError.surfaceNotFound` or a `ComponentTreeResolver.TreeError` on failure.
    public func resolvedTree(surfaceId: String) async throws -> ComponentNode {
        guard let surface = await store.surface(id: surfaceId) else {
            throw CoordinatorError.surfaceNotFound(surfaceId)
        }
        return try ComponentTreeResolver.resolve(components: surface.components)
    }

    /// Validate the topology of a surface's component tree.
    public func validate(surfaceId: String) async throws {
        guard let surface = await store.surface(id: surfaceId) else {
            throw CoordinatorError.surfaceNotFound(surfaceId)
        }
        try ComponentValidator.validateTopology(components: surface.components)
    }
}

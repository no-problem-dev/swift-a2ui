import A2UICore

/// Actor-isolated store holding all surface states.
/// Provides atomic mutations with no business logic.
public actor SurfaceStore {
    private var _surfaces: [String: SurfaceState] = [:]

    public init() {}

    /// All surfaces keyed by surface ID.
    public var surfaces: [String: SurfaceState] { _surfaces }

    /// Returns the state for the given surface ID, or nil if not found.
    public func surface(id: String) -> SurfaceState? {
        _surfaces[id]
    }

    /// Insert a new surface state, replacing any existing entry with the same ID.
    public func createSurface(_ state: SurfaceState) {
        _surfaces[state.id] = state
    }

    /// Remove the surface with the given ID.
    public func deleteSurface(id: String) {
        _surfaces.removeValue(forKey: id)
    }

    /// Merge the provided component map into the surface's existing components.
    public func updateComponents(surfaceId: String, components: [String: AnyCodable]) {
        guard _surfaces[surfaceId] != nil else { return }
        for (key, value) in components {
            _surfaces[surfaceId]!.components[key] = value
        }
    }

    /// Replace the surface's component map entirely.
    public func setComponents(surfaceId: String, components: [String: AnyCodable]) {
        _surfaces[surfaceId]?.components = components
    }

    /// Update the data model for a surface using an optional JSON Pointer path.
    /// - If `path` is non-nil and non-empty, applies a partial update via JSONPointer.
    /// - If `path` is nil/empty and `value` is non-nil, replaces the entire data model.
    /// - If `value` is nil and `path` is set, removes that path.
    public func updateDataModel(surfaceId: String, path: String?, value: AnyCodable?) {
        guard _surfaces[surfaceId] != nil else { return }
        if let path, !path.isEmpty, path != "/" {
            if let value {
                JSONPointer.set(path: path, value: value, in: &_surfaces[surfaceId]!.dataModel)
            } else {
                JSONPointer.remove(path: path, in: &_surfaces[surfaceId]!.dataModel)
            }
        } else if let value {
            _surfaces[surfaceId]!.dataModel = value
        }
    }
}

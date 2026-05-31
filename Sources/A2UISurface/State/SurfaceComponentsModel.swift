import A2UICore
import Observation

/// Manages the flat map of components for a surface (spec §3 `SurfaceComponentsModel`).
///
/// `@Observable` for structural reactivity (SwiftUI re-renders when components are added/removed);
/// also emits `onCreated`/`onDeleted` for non-SwiftUI observers.
///
/// Component lifecycle rule (spec §3): if an update provides an existing id but a **different
/// type**, the old component is removed and a fresh one created so renderers reset their state.
@Observable
public final class SurfaceComponentsModel {
    public private(set) var components: [String: ComponentModel] = [:]

    @ObservationIgnored
    public let onCreated = EventSource<ComponentModel>()
    @ObservationIgnored
    public let onDeleted = EventSource<String>()

    public init() {}

    public func get(_ id: String) -> ComponentModel? {
        components[id]
    }

    /// Apply a component definition (raw JSON object). Honors the same-id/different-type rule.
    public func apply(_ component: StructuredValue) {
        guard case .object(let dict) = component,
              case .string(let id)? = dict["id"],
              case .string(let type)? = dict["component"] else {
            return
        }
        var props = dict.dictionary
        props.removeValue(forKey: "id")
        props.removeValue(forKey: "component")

        if let existing = components[id] {
            if existing.type == type {
                // Same type: update properties in place (preserves identity/UI state).
                existing.properties = props
                return
            }
            // Different type: remove and recreate.
            components.removeValue(forKey: id)
            onDeleted.emit(id)
        }
        let model = ComponentModel(id: id, type: type, properties: props)
        components[id] = model
        onCreated.emit(model)
    }

    public func remove(_ id: String) {
        if components.removeValue(forKey: id) != nil {
            onDeleted.emit(id)
        }
    }

    public func removeAll() {
        let ids = Array(components.keys)
        components.removeAll()
        for id in ids { onDeleted.emit(id) }
    }
}

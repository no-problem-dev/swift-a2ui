import A2UICore
import Observation

/// The reactive model of a single component's raw configuration (spec §3 `ComponentModel`).
///
/// Holds the component's flat JSON properties. `@Observable` so SwiftUI re-renders when
/// `properties` change; also emits `onUpdated` for non-SwiftUI observers.
@Observable
public final class ComponentModel: Identifiable {
    public let id: String
    /// Component-type name (e.g. "Button").
    public let type: String

    public var properties: [String: StructuredValue] {
        didSet { onUpdated.emit(self) }
    }

    @ObservationIgnored
    public let onUpdated = EventSource<ComponentModel>()

    public init(id: String, type: String, properties: [String: StructuredValue] = [:]) {
        self.id = id
        self.type = type
        self.properties = properties
    }

    /// Build from a raw component object (`{ "id", "component", ...props }`). Returns nil if it
    /// lacks a string `id` or `component`.
    public static func from(_ component: StructuredValue) -> ComponentModel? {
        guard case .object(let dict) = component,
              case .string(let id)? = dict["id"],
              case .string(let type)? = dict["component"] else {
            return nil
        }
        var props = dict.dictionary
        props.removeValue(forKey: "id")
        props.removeValue(forKey: "component")
        return ComponentModel(id: id, type: type, properties: props)
    }
}

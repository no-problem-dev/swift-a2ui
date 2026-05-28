import A2UICore
import A2UISurface

/// A transient object created during rendering that pairs a component's configuration with a
/// scoped window into the data model.
///
/// Mirrors `ComponentContext` from `renderer_guide.md` §3. The framework adapter (the consumer's
/// SwiftUI layer) owns the lifecycle of this object and the bindings derived from it.
///
/// Note: `SurfaceModel`/`ComponentModel` (the `@Observable` state models) arrive in Step 4; until
/// then `ComponentContext` is built from the raw component config dictionary plus a `DataContext`.
public struct ComponentContext: Sendable {
    /// This component's unique id.
    public let componentId: String
    /// The component's component-type name (e.g. "Button").
    public let componentType: String
    /// The raw component properties (the flat JSON object minus `id`/`component`).
    public let properties: [String: AnyCodable]
    /// The scoped data window for resolving this component's bindings.
    public let dataContext: DataContext
    /// Escape hatch: look up another component's raw config in the same surface (e.g. a Row
    /// inspecting children's `weight`). Discouraged but sometimes necessary for layout.
    public let lookupComponent: @Sendable (String) -> [String: AnyCodable]?
    /// Dispatch a user action (e.g. button tap). Wired to the surface's action stream by the host.
    public let dispatch: @Sendable (_ name: String, _ context: [String: AnyCodable]) -> Void

    public init(
        componentId: String,
        componentType: String,
        properties: [String: AnyCodable],
        dataContext: DataContext,
        lookupComponent: @escaping @Sendable (String) -> [String: AnyCodable]? = { _ in nil },
        dispatch: @escaping @Sendable (_ name: String, _ context: [String: AnyCodable]) -> Void = { _, _ in }
    ) {
        self.componentId = componentId
        self.componentType = componentType
        self.properties = properties
        self.dataContext = dataContext
        self.lookupComponent = lookupComponent
        self.dispatch = dispatch
    }

    /// Build a `ComponentContext` from a raw component object (`{ "id", "component", ... }`).
    /// Returns nil if the object lacks a string `id` or `component`.
    public static func from(
        component: AnyCodable,
        dataContext: DataContext,
        lookupComponent: @escaping @Sendable (String) -> [String: AnyCodable]? = { _ in nil },
        dispatch: @escaping @Sendable (_ name: String, _ context: [String: AnyCodable]) -> Void = { _, _ in }
    ) -> ComponentContext? {
        guard case .object(let dict) = component,
              case .string(let id)? = dict["id"],
              case .string(let type)? = dict["component"] else {
            return nil
        }
        var props = dict
        props.removeValue(forKey: "id")
        props.removeValue(forKey: "component")
        return ComponentContext(
            componentId: id,
            componentType: type,
            properties: props,
            dataContext: dataContext,
            lookupComponent: lookupComponent,
            dispatch: dispatch
        )
    }
}

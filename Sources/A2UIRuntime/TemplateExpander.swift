import A2UICore
import A2UISurface
import Foundation

/// A resolved child slot produced from a `ChildList` — what the View layer needs to recurse.
///
/// `basePath` is the data scope for this child instance. For static lists it equals the parent's
/// scope; for template instances it is `/<path>/<index>` (or `/<path>/<key>` for objects), so that
/// relative bindings inside the template resolve against the correct array element (spec §scope).
public struct ResolvedChild: Sendable, Equatable {
    public let componentId: String
    public let basePath: String

    public init(componentId: String, basePath: String) {
        self.componentId = componentId
        self.basePath = basePath
    }
}

/// Expands a `ChildList` into concrete child slots, applying A2UI template/collection-scope rules.
///
/// Spec §"Collection scopes (relative paths)":
/// - Static `ids` list → each id keeps the parent scope.
/// - `template(componentId, path)` → iterate the array (or object) at `path` (resolved against the
///   parent scope), instantiating the template once per element with a child scope.
public enum TemplateExpander {

    /// Expand a `ChildList` within `context`. `context.path` is the parent's scope.
    public static func expand(_ children: ChildList, in context: DataContext) -> [ResolvedChild] {
        switch children {
        case .ids(let ids):
            return ids.map { ResolvedChild(componentId: $0, basePath: context.path) }

        case .template(let componentId, let path):
            // Resolve the bound collection against the parent scope.
            let absolutePath = JSONPointer.absolutePath(path, scope: context.path)
            guard let value = context.dataModel.get(absolutePath) else {
                return []  // progressive rendering: data not yet arrived
            }
            switch value {
            case .array(let items):
                return items.indices.map { index in
                    ResolvedChild(componentId: componentId, basePath: "\(absolutePath)/\(index)")
                }
            case .object(let dict):
                // Iterate object keys in a stable (sorted) order.
                return dict.keys.sorted().map { key in
                    ResolvedChild(componentId: componentId, basePath: "\(absolutePath)/\(key)")
                }
            default:
                return []
            }
        }
    }

    /// Convenience: decode a raw `children` property (`StructuredValue`) into a `ChildList` and expand.
    /// Returns nil if the property isn't a valid `ChildList`.
    public static func expandRaw(_ childrenProperty: StructuredValue, in context: DataContext) -> [ResolvedChild]? {
        guard let childList = decodeChildList(childrenProperty) else { return nil }
        return expand(childList, in: context)
    }

    private static func decodeChildList(_ value: StructuredValue) -> ChildList? {
        return try? value.decode(ChildList.self)
    }
}

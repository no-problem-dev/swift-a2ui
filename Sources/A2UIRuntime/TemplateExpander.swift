import StructuredDataCore
import A2UICore
import A2UISurface
import Foundation

/// One resolved child slot from a `ChildList` — everything the view layer needs in order to recurse.
///
/// `basePath` is this child instance's data scope. For a static list it equals the parent scope. For a
/// template instance it is `/<path>/<index>` (or `/<path>/<key>` for an object), which is what makes a
/// relative binding inside the template resolve against the right element (spec §scope).
public struct ResolvedChild: Sendable, Hashable {
    public let componentId: String
    public let basePath: String
    /// Zero-based index of the template iteration; `nil` for a static `ids` list.
    ///
    /// The built-in `@index` (v1.0) returns this value, so leaving it `nil` while rendering a template
    /// instance makes `@index` inside that child fail to evaluate.
    public let collectionIndex: Int?

    public init(componentId: String, basePath: String, collectionIndex: Int? = nil) {
        self.componentId = componentId
        self.basePath = basePath
        self.collectionIndex = collectionIndex
    }
}

/// Expands a `ChildList` into concrete child slots under A2UI's template and collection-scope rules.
///
/// Spec §"Collection scopes (relative paths)":
/// - A static `ids` list → every id keeps the parent scope.
/// - `template(componentId, path)` → iterate the array (or object) found at `path`, resolved from the
///   parent scope, instantiating the template once per element in that element's own child scope.
public enum TemplateExpander {

    /// Expands a `ChildList` in `context`, whose `path` is the parent scope.
    ///
    /// Returns an empty array when the bound collection has not arrived yet, or when the value there is
    /// neither an array nor an object: progressive rendering, not an error to report. Object keys are
    /// iterated in sorted order so the rows do not reshuffle between updates.
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
                    ResolvedChild(
                        componentId: componentId,
                        basePath: "\(absolutePath)/\(index)",
                        collectionIndex: index
                    )
                }
            case .object(let dict):
                // Iterate object keys in a stable (sorted) order.
                return dict.keys.sorted().enumerated().map { offset, key in
                    ResolvedChild(
                        componentId: componentId,
                        basePath: "\(absolutePath)/\(key)",
                        collectionIndex: offset
                    )
                }
            default:
                return []
            }
        }
    }

    /// Decodes a raw `children` property into a `ChildList` and expands it.
    ///
    /// - Returns: `nil` when the value is not a valid `ChildList` — distinct from `[]`, which means a
    ///   valid list that currently yields no children.
    public static func expandRaw(_ childrenProperty: StructuredValue, in context: DataContext) -> [ResolvedChild]? {
        guard let childList = decodeChildList(childrenProperty) else { return nil }
        return expand(childList, in: context)
    }

    private static func decodeChildList(_ value: StructuredValue) -> ChildList? {
        return try? value.decode(ChildList.self)
    }
}

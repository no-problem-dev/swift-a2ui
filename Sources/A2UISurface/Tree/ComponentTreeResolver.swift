import StructuredDataCore
import A2UICore

/// Turns the flat component dictionary an agent sends into a tree rooted at the component with id
/// `"root"`.
///
/// The agent addresses components by id and refers to children by id, so nothing in the payload is
/// nested. Resolution walks those references once and is where cycles and runaway depth are caught,
/// before a renderer can recurse on them.
public enum ComponentTreeResolver {

    /// Reasons resolution stops without a tree.
    public enum TreeError: Error, Sendable, Equatable {
        /// The dictionary has no component with the id `"root"`.
        case missingRoot
        /// The component with this id is reachable from itself through its child fields.
        case circularReference(String)
        /// The tree is deeper than `maxDepth`; the payload is the depth at which resolution stopped.
        case depthLimitExceeded(Int)
        /// Ids present in the dictionary that nothing in the tree references.
        case orphanedComponents([String])
    }

    /// The depth at which resolution throws `depthLimitExceeded` instead of recursing further.
    public static let maxDepth = 50

    /// Builds the tree from a flat component dictionary, starting at the component with id `"root"`.
    ///
    /// A child id that is not present in the dictionary is skipped without comment, so a payload
    /// with a broken reference resolves to a smaller tree rather than failing. The three faults that
    /// do stop resolution are a missing root, a cycle, and a tree deeper than `maxDepth`.
    /// - Throws: A ``TreeError`` describing which of those three it hit.
    public static func resolve(components: [String: StructuredValue]) throws -> ComponentNode {
        guard let rootComponent = components["root"] else {
            throw TreeError.missingRoot
        }

        var visited: Set<String> = []
        let tree = try buildNode(
            id: "root",
            component: rootComponent,
            components: components,
            visited: &visited,
            depth: 0
        )

        return tree
    }

    // MARK: - Private

    private static func buildNode(
        id: String,
        component: StructuredValue,
        components: [String: StructuredValue],
        visited: inout Set<String>,
        depth: Int
    ) throws -> ComponentNode {
        guard depth < maxDepth else {
            throw TreeError.depthLimitExceeded(depth)
        }

        guard !visited.contains(id) else {
            throw TreeError.circularReference(id)
        }

        visited.insert(id)

        let childIds = extractChildIds(from: component)
        var children: [ComponentNode] = []

        for childId in childIds {
            if let childComponent = components[childId] {
                let childNode = try buildNode(
                    id: childId,
                    component: childComponent,
                    components: components,
                    visited: &visited,
                    depth: depth + 1
                )
                children.append(childNode)
            }
        }

        visited.remove(id)

        return ComponentNode(id: id, component: component, children: children)
    }

    /// Extract child component IDs from a component's JSON.
    /// Looks for "child", "children", "trigger", "content", and "tabs" fields.
    private static func extractChildIds(from component: StructuredValue) -> [String] {
        guard case .object(let dict) = component else { return [] }
        var ids: [String] = []

        // Single-child fields
        for key in ["child", "trigger", "content"] {
            if case .string(let childId) = dict[key] {
                ids.append(childId)
            }
        }

        // Multi-child or template children
        if let children = dict["children"] {
            switch children {
            case .array(let arr):
                for item in arr {
                    if case .string(let childId) = item {
                        ids.append(childId)
                    }
                }
            case .object(let tmpl):
                // Template object: { componentId: "...", path: "..." }
                if case .string(let componentId) = tmpl["componentId"] {
                    ids.append(componentId)
                }
            default:
                break
            }
        }

        // Tabs: array of objects with a "child" key
        if case .array(let tabs) = dict["tabs"] {
            for tab in tabs {
                if case .object(let tabDict) = tab,
                   case .string(let childId) = tabDict["child"] {
                    ids.append(childId)
                }
            }
        }

        return ids
    }

    private static func collectIds(from node: ComponentNode) -> Set<String> {
        var ids: Set<String> = [node.id]
        for child in node.children {
            ids.formUnion(collectIds(from: child))
        }
        return ids
    }
}

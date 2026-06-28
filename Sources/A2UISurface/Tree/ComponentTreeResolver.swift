import A2UICore

/// フラットなコンポーネント辞書を "root" コンポーネントを頂点とするツリーへ解決する。
public enum ComponentTreeResolver {

    /// ツリー解決時のエラー。
    public enum TreeError: Error, Sendable, Equatable {
        /// id "root" を持つコンポーネントが存在しない。
        case missingRoot
        /// 指定した id でコンポーネントの循環参照を検出した。
        case circularReference(String)
        /// ツリーの深さが `maxDepth` を超過した。
        case depthLimitExceeded(Int)
        /// どのコンポーネントからも参照されない孤立コンポーネントが存在する。
        case orphanedComponents([String])
    }

    /// `depthLimitExceeded` を throw するツリー深度の上限。
    public static let maxDepth = 50

    /// フラットなコンポーネント辞書からツリーを構築する。
    /// id "root" を持つコンポーネントが必須のルートとなる。
    /// "root" コンポーネントが存在しない場合は `TreeError.missingRoot` を throw する。
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

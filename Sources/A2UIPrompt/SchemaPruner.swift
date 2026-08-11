import StructuredDataCore
import A2UICore
import Foundation

/// Pure functions that prune a JSON Schema down to what a prompt actually needs.
///
/// A literal port of `with_pruning`, `_with_pruned_components`, `_with_pruned_messages`,
/// `_with_pruned_common_types`, `_collect_refs`, and `_prune_defs_by_reachability` from the
/// official Python SDK (`agent_sdks/python/src/a2ui/schema/catalog.py`). Every prune case in
/// the official conformance suite (`agent_sdks/conformance/suites/catalog.yaml`) is pinned by
/// a test, so these functions must keep matching the Python side even where its behaviour
/// looks arbitrary — the odd cases below are deliberate, not oversights.
///
/// A model never dereferences the URLs inside the schema, so unused type definitions are pure
/// noise; removing them is where the token savings come from.
public enum SchemaPruner {

    // MARK: - Public API

    /// Applies the three pruning stages to a catalog triple; the equivalent of the official
    /// `A2uiCatalog.with_pruning`.
    ///
    /// 1. When `allowedComponents` is given: narrows the catalog's `components` and
    ///    `$defs.anyComponent.oneOf`.
    /// 2. When `allowedMessages` is given: narrows agent_to_renderer's `oneOf` or `properties`
    ///    together with its `$defs`.
    /// 3. **Always**: keeps only the `common_types` `$defs` reachable from the pruned catalog
    ///    and agent_to_renderer.
    ///
    /// The order is normative. Common-types reachability is computed from the **already
    /// narrowed** catalog and agent_to_renderer, so stage 3 cannot be run first or in
    /// isolation — doing so retains definitions the pruned schemas no longer reference.
    ///
    /// A `nil` allowlist skips its stage entirely; an **empty** allowlist is a no-op that
    /// keeps everything, which is the official behaviour and not a way to prune to nothing.
    public static func withPruning(
        catalog: StructuredValue,
        agentToRenderer: StructuredValue,
        commonTypes: StructuredValue,
        allowedComponents: Set<String>? = nil,
        allowedMessages: Set<String>? = nil
    ) -> (catalog: StructuredValue, agentToRenderer: StructuredValue, commonTypes: StructuredValue) {
        var catalog = catalog
        var s2c = agentToRenderer
        if let allowedComponents {
            catalog = pruneComponents(catalog: catalog, allowedComponents: allowedComponents)
        }
        if let allowedMessages {
            s2c = pruneMessages(agentToRenderer: s2c, allowedMessages: allowedMessages)
        }
        let common = pruneCommonTypes(commonTypes: commonTypes, reachableFrom: [catalog, s2c])
        return (catalog, s2c, common)
    }

    /// Narrows the catalog's `components` to an allowlist; the equivalent of the official
    /// `_with_pruned_components`.
    ///
    /// Also strips the `$ref`s to the excluded components from `$defs.anyComponent.oneOf`, so
    /// the union type stays consistent with the component definitions that survive.
    ///
    /// An empty allowlist is a no-op that keeps everything, as in the official implementation.
    /// Note what happens to unusual `oneOf` entries: anything that is not a `$ref`, or whose
    /// reference does not start with `#/components/`, is **dropped** rather than preserved —
    /// so a catalog that inlines a component schema in `oneOf` loses it here.
    public static func pruneComponents(
        catalog: StructuredValue,
        allowedComponents: Set<String>
    ) -> StructuredValue {
        guard !allowedComponents.isEmpty,
              case .object(var root) = catalog else { return catalog }

        // 1. Filter the components themselves.
        if case .object(let components)? = root["components"] {
            root["components"] = .object(OrderedObject(components.filter { allowedComponents.contains($0.key) }))
        }

        // 2. Remove the disallowed "#/components/X" references from $defs.anyComponent.oneOf.
        if case .object(var defs)? = root["$defs"],
           case .object(var anyComponent)? = defs["anyComponent"],
           case .array(let oneOf)? = anyComponent["oneOf"] {
            let prefix = "#/components/"
            let filtered = oneOf.filter { item in
                guard case .object(let dict) = item,
                      case .string(let ref)? = dict["$ref"],
                      ref.hasPrefix(prefix) else {
                    return false  // Official behaviour: drop non-$ref and unrecognized entries.
                }
                return allowedComponents.contains(String(ref.dropFirst(prefix.count)))
            }
            anyComponent["oneOf"] = .array(filtered)
            defs["anyComponent"] = .object(anyComponent)
            root["$defs"] = .object(defs)
        }

        return .object(root)
    }

    /// Narrows agent_to_renderer to a message allowlist; the equivalent of the official
    /// `_with_pruned_messages`.
    ///
    /// Two schema shapes are handled, chosen by what the root object actually contains:
    ///
    /// - `oneOf` plus `$defs` (v0.9 and later): keeps only the allowed `#/$defs/X` branches of
    ///   `oneOf`, then narrows `$defs` by a reachability walk seeded from those names.
    /// - `properties` at the root (v0.8): narrows `properties` by the same walk.
    ///
    /// An empty allowlist is a no-op, as in the official implementation. Entries in `oneOf`
    /// that are not a `$ref`, or whose reference does not start with `#/$defs/`, are dropped.
    /// Names in the allowlist that the schema does not define are ignored rather than
    /// rejected, so a stale allowlist silently prunes further than intended.
    public static func pruneMessages(
        agentToRenderer: StructuredValue,
        allowedMessages: Set<String>
    ) -> StructuredValue {
        guard !allowedMessages.isEmpty,
              case .object(var root) = agentToRenderer else { return agentToRenderer }

        if case .array(let oneOf)? = root["oneOf"] {
            // v0.9 and later: keep only the allowed "#/$defs/X" branches (official: drop the rest).
            let filtered = oneOf.filter { item in
                guard case .object(let dict) = item,
                      case .string(let ref)? = dict["$ref"],
                      let name = lastSegment(ofInternalRef: ref) else {
                    return false
                }
                return allowedMessages.contains(name)
            }
            root["oneOf"] = .array(filtered)

            if case .object(let defs)? = root["$defs"] {
                let pruned = pruneByReachability(
                    defs: defs,
                    roots: allowedMessages,
                    internalRefPrefix: "#/$defs/"
                )
                root["$defs"] = .object(pruned)
            }
        } else if case .object(let properties)? = root["properties"] {
            // v0.8: the messages sit directly under properties.
            let pruned = pruneByReachability(
                defs: properties,
                roots: allowedMessages,
                internalRefPrefix: "#/properties/"
            )
            root["properties"] = .object(pruned)
        }

        return .object(root)
    }

    /// Narrows the `$defs` of `common_types` to the definitions the given schemas reference.
    ///
    /// Cross-references between `$defs` entries are followed to their transitive closure, in
    /// both the internal form (`#/$defs/X`) and the absolute form
    /// (`<URL>/common_types.json#/$defs/X`) that the published schemas use.
    ///
    /// - Parameters:
    ///   - commonTypes: The parsed common_types schema; returned untouched when it has no
    ///     `$defs` to narrow.
    ///   - reachableFrom: The schemas whose `$ref`s seed the walk — the catalog and
    ///     agent_to_renderer, and they must already be pruned, or definitions that the pruned
    ///     schemas dropped are kept alive.
    /// - Returns: The schema with only the reachable `$defs` remaining.
    public static func pruneCommonTypes(
        commonTypes: StructuredValue,
        reachableFrom externalSchemas: [StructuredValue]
    ) -> StructuredValue {
        guard case .object(var root) = commonTypes,
              case .object(let defs)? = root["$defs"] else {
            return commonTypes
        }

        // 1. Collect every "common_types.json#/$defs/X" $ref from the external schemas.
        var rootNames: Set<String> = []
        for schema in externalSchemas {
            for ref in collectRefs(in: schema) {
                if let name = name(ofCommonTypesRef: ref) {
                    rootNames.insert(name)
                }
            }
        }

        // 2. Take the transitive closure of the internal cross-references by BFS, accepting
        //    both the "#/$defs/X" form and the absolute URL form.
        var visited: Set<String> = []
        var queue: [String] = Array(rootNames)
        while !queue.isEmpty {
            let name = queue.removeFirst()
            guard defs[name] != nil, !visited.contains(name) else { continue }
            visited.insert(name)
            for ref in collectRefs(in: defs[name]!) {
                if let inner = lastSegment(ofInternalRef: ref) ?? self.name(ofCommonTypesRef: ref) {
                    queue.append(inner)
                }
            }
        }
        root["$defs"] = .object(OrderedObject(defs.filter { visited.contains($0.key) }))
        return .object(root)
    }

    /// Collects every `$ref` value in a JSON structure, at any depth.
    ///
    /// The values come back raw, so both the internal (`#/$defs/X`) and absolute URL forms
    /// appear side by side and the caller decides which prefix it cares about.
    public static func collectRefs(in value: StructuredValue) -> Set<String> {
        var refs: Set<String> = []
        collectRefsInternal(value, into: &refs)
        return refs
    }

    // MARK: - Internal

    /// Narrows `defs` to the entries reachable from `roots` through refs that begin with
    /// `internalRefPrefix`.
    ///
    /// Only that one prefix is followed, so refs into another document are treated as leaves.
    /// Names in `roots` with no matching entry are skipped, which is how an allowlist may name
    /// something the schema does not define without failing.
    static func pruneByReachability(
        defs: OrderedObject,
        roots: Set<String>,
        internalRefPrefix: String
    ) -> OrderedObject {
        var visited: Set<String> = []
        var queue: [String] = Array(roots)

        while let name = queue.popFirst() {
            guard defs[name] != nil, !visited.contains(name) else { continue }
            visited.insert(name)
            for ref in collectRefs(in: defs[name]!) {
                if ref.hasPrefix(internalRefPrefix) {
                    let key = String(ref.dropFirst(internalRefPrefix.count))
                    queue.append(key)
                }
            }
        }

        return OrderedObject(defs.filter { visited.contains($0.key) })
    }

    private static func collectRefsInternal(_ value: StructuredValue, into refs: inout Set<String>) {
        switch value {
        case .object(let dict):
            for (key, child) in dict {
                if key == "$ref", case .string(let s) = child {
                    refs.insert(s)
                } else {
                    collectRefsInternal(child, into: &refs)
                }
            }
        case .array(let arr):
            for item in arr {
                collectRefsInternal(item, into: &refs)
            }
        default:
            break
        }
    }

    /// `"https://.../common_types.json#/$defs/DynamicString"` -> `"DynamicString"`
    private static func name(ofCommonTypesRef ref: String) -> String? {
        let marker = "common_types.json#/$defs/"
        guard let range = ref.range(of: marker) else { return nil }
        return String(ref[range.upperBound...])
    }

    /// `"#/$defs/CreateSurfaceMessage"` -> `"CreateSurfaceMessage"`
    private static func lastSegment(ofInternalRef ref: String) -> String? {
        let prefix = "#/$defs/"
        guard ref.hasPrefix(prefix) else { return nil }
        return String(ref.dropFirst(prefix.count))
    }
}

// MARK: - Array popFirst helper

private extension Array {
    mutating func popFirst() -> Element? {
        guard !isEmpty else { return nil }
        return removeFirst()
    }
}

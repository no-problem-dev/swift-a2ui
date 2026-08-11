import StructuredDataCore
import A2UICore

/// Rejects component payloads a renderer cannot safely build: an unwalkable tree, or ids that
/// collide.
///
/// Run this before handing components to ``ComponentTreeResolver`` in production, so a malformed
/// agent message fails at a named error rather than as a partially built tree.
public enum ComponentValidator {

    /// Reasons a component payload is rejected.
    public enum ValidationError: Error, Sendable, Equatable {
        /// Two or more components in the payload share this id.
        case duplicateId(String)
        /// No component has the id `"root"`, so the tree has no entry point.
        case missingRoot
        /// The component with this id is reachable from itself through its child fields.
        case circularReference(String)
        /// The tree is deeper than `ComponentTreeResolver.maxDepth`.
        case depthLimitExceeded
    }

    /// Validates topology by resolving the tree and discarding it, keeping only the faults.
    ///
    /// Catches a missing root, a cycle, and excessive depth. Components that nothing references,
    /// and child ids that reference nothing, both pass — this checks that the tree can be walked,
    /// not that the payload is tidy.
    /// - Throws: A ``ValidationError`` naming the fault.
    public static func validateTopology(components: [String: StructuredValue]) throws {
        guard components["root"] != nil else {
            throw ValidationError.missingRoot
        }

        do {
            _ = try ComponentTreeResolver.resolve(components: components)
        } catch ComponentTreeResolver.TreeError.circularReference(let id) {
            throw ValidationError.circularReference(id)
        } catch ComponentTreeResolver.TreeError.depthLimitExceeded {
            throw ValidationError.depthLimitExceeded
        } catch ComponentTreeResolver.TreeError.missingRoot {
            throw ValidationError.missingRoot
        }
    }

    /// Checks that no component id repeats in a flat `StructuredValue` array.
    ///
    /// Each element is expected to be an object with a string `"id"` field. Elements shaped any
    /// other way — no `"id"`, a non-string `"id"`, not an object at all — are skipped rather than
    /// rejected, so passing an array of the wrong shape succeeds without checking anything.
    /// - Throws: `ValidationError.duplicateId` with the first id seen twice.
    public static func validateUniqueIds(components: [StructuredValue]) throws {
        var seen: Set<String> = []
        for component in components {
            if case .object(let dict) = component,
               case .string(let id) = dict["id"] {
                if seen.contains(id) {
                    throw ValidationError.duplicateId(id)
                }
                seen.insert(id)
            }
        }
    }
}

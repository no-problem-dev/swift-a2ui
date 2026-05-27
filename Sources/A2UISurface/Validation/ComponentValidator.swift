import A2UICore

/// Validates component topology and ID uniqueness.
public enum ComponentValidator {

    public enum ValidationError: Error, Sendable, Equatable {
        case duplicateId(String)
        case missingRoot
        case circularReference(String)
        case depthLimitExceeded
    }

    /// Validate component topology using the tree resolver.
    /// Checks for: missing root, circular references, depth limit.
    public static func validateTopology(components: [String: AnyCodable]) throws {
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

    /// Validate that all component IDs within a flat AnyCodable array are unique.
    /// Each element is expected to be an object with an "id" string field.
    public static func validateUniqueIds(components: [AnyCodable]) throws {
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

import JSONParsing
import StructuredDataCore
import A2UICore
import Foundation

/// Removes the FunctionCall-related `$defs` from `common_types.json`.
///
/// **Unofficial optimization.** The A2UI specification neither forbids nor recommends a catalog
/// without `functions`. For an app that declares `functions: []`, deleting the `FunctionCall`
/// and `DynamicValue` definitions — and the FunctionCall branch inside each `Dynamic*` type's
/// `oneOf` — is what convinces the model that the call form is unavailable. Merely omitting the
/// functions from the catalog is not enough: a model that still sees the type in the schema will
/// emit it.
///
/// What comes out:
/// - The `$def`s for `FunctionCall` and `DynamicValue` are gone.
/// - The `allOf` entries referencing FunctionCall are gone from the `oneOf` of `DynamicString`,
///   `DynamicNumber`, `DynamicBoolean`, and `DynamicStringList`.
/// - A subsequent `SchemaPruner.pruneCommonTypes` then drops whatever became unreachable.
public enum CommonTypesCompactor {

    /// Returns the common_types schema with FunctionCall support removed.
    ///
    /// Input that does not parse comes back unchanged, so a malformed schema degrades to the
    /// full prompt rather than to an empty schema block — but it also means a silent no-op is
    /// indistinguishable from a catalog that had nothing to remove.
    public static func compact(_ commonTypesJSON: String) -> String {
        guard let data = commonTypesJSON.data(using: .utf8),
              let value = try? JSONParser().parse(data),
              case .object(var root) = value else {
            return commonTypesJSON
        }

        // 1. Delete FunctionCall and DynamicValue from $defs.
        if case .object(var defs)? = root["$defs"] {
            defs.removeValue(forKey: "FunctionCall")
            defs.removeValue(forKey: "DynamicValue")

            // 2. Drop the entries that reference FunctionCall from every $defs entry's oneOf.
            for key in defs.keys {
                if let updated = stripFunctionCallReferences(in: defs[key]!) {
                    defs[key] = updated
                }
            }
            root["$defs"] = .object(defs)
        }

        return serialize(.object(root)) ?? commonTypesJSON
    }

    /// Recursively removes the `oneOf` entries that reference FunctionCall, whether directly or
    /// through an `allOf`.
    ///
    /// Returns `nil` for scalars, which callers read as "nothing to replace here". A type whose
    /// every branch referenced FunctionCall loses its `oneOf` key entirely rather than keeping
    /// an empty array, since an empty `oneOf` validates nothing.
    private static func stripFunctionCallReferences(in value: StructuredValue) -> StructuredValue? {
        switch value {
        case .object(var dict):
            // Walk "oneOf": [...] and drop the entries that reference FunctionCall.
            if case .array(let arr)? = dict["oneOf"] {
                let filtered = arr.filter { !containsFunctionCallReference($0) }
                if filtered.isEmpty {
                    dict.removeValue(forKey: "oneOf")
                } else {
                    dict["oneOf"] = .array(filtered)
                }
            }
            // Recurse into nested dictionaries.
            for (key, child) in dict {
                if let updated = stripFunctionCallReferences(in: child) {
                    dict[key] = updated
                }
            }
            return .object(dict)

        case .array(let arr):
            return .array(arr.compactMap { stripFunctionCallReferences(in: $0) ?? $0 })

        default:
            return nil
        }
    }

    /// Reports whether a value references FunctionCall, as a direct `$ref` or inside an `allOf`.
    ///
    /// Only those two shapes count; a reference buried deeper is not detected, which matches
    /// how the published common_types writes its `Dynamic*` branches.
    private static func containsFunctionCallReference(_ value: StructuredValue) -> Bool {
        switch value {
        case .object(let dict):
            if case .string(let ref)? = dict["$ref"], isFunctionCallRef(ref) {
                return true
            }
            if case .array(let inner)? = dict["allOf"] {
                return inner.contains(where: containsFunctionCallReference)
            }
            return false
        default:
            return false
        }
    }

    private static func isFunctionCallRef(_ ref: String) -> Bool {
        ref == "#/$defs/FunctionCall" || ref.hasSuffix("common_types.json#/$defs/FunctionCall")
    }

    private static func serialize(_ value: StructuredValue) -> String? {
        return JSONSerializer(options: .init(sortKeys: true)).string(from: value)
    }
}

import A2UICore
import A2UISurface

/// Validates parsed A2UI messages against a catalog **before rendering** — the Swift counterpart of
/// the official Python `A2uiValidator.validate()`. Returns a list of human-readable issues (empty =
/// valid) so a host can decide to re-prompt the model (the spec's prompt → generate → validate loop).
///
/// Mirrors the official checks as closely as the typed pipeline allows, per surface:
/// - **no output**: neither a `createSurface` nor any `updateComponents` was produced;
/// - **component integrity**: duplicate ids, missing `root`, circular references, excessive depth;
/// - **catalog miss**: a `component` name not in this catalog (renders as a "Not Supported" fallback);
/// - **structural failure**: a known component whose props fail to decode (e.g. a `Button` with no
///   `action`) — the official schema's `required` check.
public enum A2UIValidation {

    /// Collect validation issues for the messages of a turn. Empty result means the output is valid
    /// and safe to render. Components are aggregated per `surfaceId` across `createSurface`
    /// (v0.10 inline components) and `updateComponents` before validating.
    ///
    /// `allowedComponents` / `allowedMessages` mirror `A2UIPromptBuilder`'s pruning sets: when a
    /// host prunes the prompt-side schema to a subset, it passes the same sets here so a component
    /// or message the model was never offered is rejected — prompt and enforcement stay in lockstep
    /// (`nil` = no restriction beyond the catalog itself).
    public static func issues<Catalog: A2UICatalog>(
        in messages: [ServerMessage],
        for catalog: Catalog.Type,
        allowedComponents: Set<String>? = nil,
        allowedMessages: Set<String>? = nil
    ) -> [String] {
        var componentsBySurface: [String: [StructuredValue]] = [:]
        var order: [String] = []
        var sawSurface = false
        var sawStateChange = false
        var activeSurfaces: Set<String> = []
        var duplicateIssues: [String] = []

        func note(_ surfaceId: String) {
            if !order.contains(surfaceId) { order.append(surfaceId) }
        }

        // Message-allowlist check first: a pruned-out message type was never in the model's schema,
        // so the corrective feedback names the violation directly instead of a downstream symptom.
        var messageIssues: [String] = []
        if let allowedMessages {
            for name in Set(messages.map(\.schemaMessageName)).subtracting(allowedMessages).sorted() {
                messageIssues.append("message type '\(name)' is not allowed for this agent"
                    + " (allowed: \(allowedMessages.sorted().joined(separator: ", ")))")
            }
        }

        for message in messages {
            switch message {
            case .createSurface(let cs):
                sawSurface = true
                note(cs.surfaceId)
                // Per the spec it is an error to recreate an existing surfaceId; only a
                // prior deleteSurface frees the id (mirrors the official eval validator).
                if activeSurfaces.contains(cs.surfaceId) {
                    duplicateIssues.append(
                        "duplicate createSurface for surface '\(cs.surfaceId)' without prior deleteSurface")
                }
                activeSurfaces.insert(cs.surfaceId)
                if let comps = cs.components {
                    componentsBySurface[cs.surfaceId, default: []].append(contentsOf: comps)
                }
            case .updateComponents(let uc):
                note(uc.surfaceId)
                componentsBySurface[uc.surfaceId, default: []].append(contentsOf: uc.components)
            case .deleteSurface(let ds):
                // The recreated surface starts fresh, so earlier components no longer count
                // toward duplicate-id / topology checks.
                activeSurfaces.remove(ds.surfaceId)
                componentsBySurface[ds.surfaceId] = nil
                sawStateChange = true
            case .updateDataModel:
                // A data-model-only batch is a legitimate incremental update to an existing
                // surface (the smallest change a turn can make) — never "no output".
                sawStateChange = true
            default:
                break
            }
        }

        if !sawSurface && componentsBySurface.isEmpty && !sawStateChange {
            return messageIssues + ["no A2UI surface or components were produced"]
        }

        var issues: [String] = messageIssues + duplicateIssues
        for surfaceId in order {
            let comps = componentsBySurface[surfaceId] ?? []
            // A createSurface with no components yet is valid (components may arrive in a later message
            // of the same turn — but here we have the whole turn, so an empty surface just renders blank).
            guard !comps.isEmpty else { continue }

            // 1) Unique component ids within the surface.
            do {
                try ComponentValidator.validateUniqueIds(components: comps)
            } catch let ComponentValidator.ValidationError.duplicateId(id) {
                issues.append("surface '\(surfaceId)': duplicate component id '\(id)'")
            } catch {}

            // 2) Topology: a 'root' must exist, with no circular references or runaway depth.
            var byId: [String: StructuredValue] = [:]
            for component in comps {
                if case .object(let dict) = component, case .string(let id) = dict["id"] {
                    byId[id] = component
                }
            }
            do {
                try ComponentValidator.validateTopology(components: byId)
            } catch ComponentValidator.ValidationError.missingRoot {
                // First paint must include 'root'. An update batch (no createSurface for this
                // surface in the turn) may legitimately touch only subtrees — the root already
                // lives on the client.
                if activeSurfaces.contains(surfaceId) {
                    issues.append("surface '\(surfaceId)': missing a component with id 'root'")
                }
            } catch let ComponentValidator.ValidationError.circularReference(id) {
                issues.append("surface '\(surfaceId)': circular reference at component '\(id)'")
            } catch ComponentValidator.ValidationError.depthLimitExceeded {
                issues.append("surface '\(surfaceId)': component tree exceeds the depth limit")
            } catch {}

            // 3) Per-component: allowlist miss + unknown component names + malformed known components.
            for component in comps {
                let probedId = (try? component.decode(IdProbe.self))?.id ?? ""
                // Allowlist before catalog checks: a pruned-out component is "not allowed" — the
                // message that matches the schema the model actually saw — not "unknown"/"malformed".
                if let allowedComponents,
                   case .object(let dict) = component, case .string(let name) = dict["component"],
                   !allowedComponents.contains(name) {
                    issues.append("surface '\(surfaceId)': component '\(name)'"
                        + (probedId.isEmpty ? "" : " (id: \(probedId))")
                        + " is not allowed for this agent"
                        + " (allowed: \(allowedComponents.sorted().joined(separator: ", ")))")
                    continue
                }
                do {
                    let node = try component.decode(CatalogNode<Catalog.Node>.self)
                    if case .unknown(let name, let id, _) = node {
                        issues.append("surface '\(surfaceId)': unknown component '\(name)'"
                            + (id.isEmpty ? "" : " (id: \(id))"))
                    }
                } catch {
                    issues.append("surface '\(surfaceId)': malformed component"
                        + (probedId.isEmpty ? "" : " '\(probedId)'") + " — \(shortReason(error))")
                }
            }
        }
        return issues
    }

    private struct IdProbe: Decodable { let id: String? }

    /// Keep decode-error text short enough to ride along in a corrective prompt without flooding it.
    private static func shortReason(_ error: Error) -> String {
        String("\(error)".prefix(160))
    }
}

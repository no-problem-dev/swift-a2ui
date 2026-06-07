import A2ACore
import A2UICore
import A2UIA2A

/// Which agent owns which surface — the conversation-scoped ledger behind both deterministic
/// userAction routing and data-model stripping (the official sample's `SubagentRouteManager`,
/// which is a stateless accessor pair over ADK session state; here the ledger is a value the
/// host session owns).
///
/// One writer, two readers:
/// - written when a subagent's response creates a surface (`record(surfacesCreatedIn:by:)`)
/// - read to route a userAction back to its owner without an LLM call (`owner(ofUserActionIn:)`)
/// - read to scope the client data model to what the target agent may see (`outboundMetadata`)
public struct SurfaceOwnership: Sendable, Equatable {
    private var owners: [String: String] = [:]

    public init() {}

    public func owner(of surfaceId: String) -> String? {
        owners[surfaceId]
    }

    /// Last writer wins, matching the official `set_route_to_subagent_name` overwrite semantics.
    public mutating func record(owner agent: String, of surfaceId: String) {
        owners[surfaceId] = agent
    }

    public func surfaceIds(ownedBy agent: String) -> Set<String> {
        Set(owners.filter { $0.value == agent }.keys)
    }
}

// MARK: - Recording (mirror of the official agent_executor's event observation)

extension SurfaceOwnership {
    /// Records `agent` as the owner of every surface created in `parts`.
    ///
    /// The official sample observes `beginRendering` on each outbound subagent event;
    /// v0.10's surface-creating message is `createSurface`. Call this on every batch of
    /// parts received from a subagent, with the subagent's name as `agent`
    /// (the official `event.author`).
    public mutating func record(surfacesCreatedIn parts: [Part], by agent: String) {
        for part in parts {
            guard case .createSurface(let creation)? = try? part.a2uiServerMessage() else { continue }
            record(owner: agent, of: creation.surfaceId)
        }
    }
}

// MARK: - Deterministic routing (mirror of the official before_model_callback)

extension SurfaceOwnership {
    /// The agent to route the message to without any LLM call, or `nil` to fall back to
    /// LLM routing.
    ///
    /// Like the official `programmtically_route_user_action_to_subagent`, only the trailing
    /// part is considered, and an unknown surface or unreadable action reads as `nil` —
    /// deterministic routing is an optimization, never a correctness gate.
    public func owner(ofUserActionIn parts: [Part]) -> String? {
        guard let action = parts.last?.a2uiUserAction else { return nil }
        return owner(of: action.surfaceId)
    }
}

// MARK: - Outbound metadata (mirror of the official A2UIMetadataInterceptor)

extension SurfaceOwnership {
    /// Prepares message metadata bound for `agent`: embeds the client capabilities and strips
    /// the client data model down to the agent's own surfaces (the official "Data Model
    /// Stripping to prevent data leakage" — an agent never sees another agent's surface data).
    ///
    /// Stripping applies whenever a data model is present, even to an empty surface set,
    /// matching the official interceptor.
    public func outboundMetadata(
        _ metadata: A2AMetadata?,
        capabilities: A2UIClientCapabilities?,
        for agent: String
    ) throws -> A2AMetadata? {
        var result = metadata ?? [:]
        if let capabilities {
            try A2UIMessageMetadata.embed(capabilities, into: &result)
        }
        if let dataModel = A2UIMessageMetadata.clientDataModel(in: result) {
            try A2UIMessageMetadata.embed(dataModel.keeping(surfaceIds(ownedBy: agent)), into: &result)
        }
        return result.isEmpty ? nil : result
    }
}

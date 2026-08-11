import A2ACore
import A2UICore
import A2UIA2A

/// A conversation-scoped ledger of which agent owns which surface.
///
/// It backs two things at once: routing a `userAction` to its owner without an LLM call, and
/// stripping the client data model down to what an agent is allowed to see. The official sample's
/// `SubagentRouteManager` holds the same state as a pair of stateless accessors over ADK session
/// state; this is a value-type ledger the host session owns and persists itself.
///
/// One write, two reads:
/// - Write when a subagent's response creates surfaces (`record(surfacesCreatedIn:by:)`).
/// - Read to route a `userAction` to its owner (`owner(ofUserActionIn:)`).
/// - Read to narrow the client data model to what the target agent may see (`outboundMetadata`).
///
/// Ownership is scoped to one conversation. Reusing a ledger across conversations would let a
/// surface id from an earlier exchange decide where a later message is routed and what data travels
/// with it.
public struct SurfaceOwnership: Sendable, Equatable {
    private var owners: [String: String] = [:]

    public init() {}

    /// The agent that most recently claimed `surfaceId`, or `nil` if none has.
    public func owner(of surfaceId: String) -> String? {
        owners[surfaceId]
    }

    /// Claims `surfaceId` for `agent`, replacing whatever owner it had.
    ///
    /// Last write wins, matching the overwrite semantics of the official
    /// `set_route_to_subagent_name`. A second agent creating the same surface id therefore takes
    /// over both routing and data model access for it.
    public mutating func record(owner agent: String, of surfaceId: String) {
        owners[surfaceId] = agent
    }

    /// Every surface currently claimed by `agent` — the exact set that survives data model
    /// stripping in `outboundMetadata(_:capabilities:for:)`.
    public func surfaceIds(ownedBy agent: String) -> Set<String> {
        Set(owners.filter { $0.value == agent }.keys)
    }
}

// MARK: - Recording (mirror of the official agent_executor's event observation)

extension SurfaceOwnership {
    /// Records `agent` as the owner of every surface created in `parts`.
    ///
    /// The official sample observes `beginRendering` on each outbound subagent event; in v1.0 the
    /// surface-creating message is `createSurface`. Call this once per batch of parts received from
    /// a subagent, passing that subagent's name (the official `event.author`) as `agent`.
    ///
    /// Parts that do not decode as an A2UI agent message are skipped without error, so a surface
    /// carried in a part this cannot read stays unowned — its `userAction` falls back to LLM
    /// routing, and its data is stripped from every outbound message.
    public mutating func record(surfacesCreatedIn parts: [Part], by agent: String) {
        for part in parts {
            guard case .createSurface(let creation)? = try? part.a2uiAgentMessage() else { continue }
            record(owner: agent, of: creation.surfaceId)
        }
    }
}

// MARK: - Deterministic routing (mirror of the official before_model_callback)

extension SurfaceOwnership {
    /// The agent this message can be routed to without an LLM call, or `nil` when the surface is
    /// unknown or the action cannot be read.
    ///
    /// `nil` means "fall back to LLM routing", not "drop the message": deterministic routing is an
    /// optimization, never a correctness gate, so a wrong answer here costs a round trip and not a
    /// misdelivery. Like the official `programmtically_route_user_action_to_subagent`, only the last
    /// part is examined — an earlier `userAction` in the same batch is ignored.
    public func owner(ofUserActionIn parts: [Part]) -> String? {
        guard let action = parts.last?.a2uiUserAction else { return nil }
        return owner(of: action.surfaceId)
    }
}

// MARK: - Outbound metadata (mirror of the official A2UIMetadataInterceptor)

extension SurfaceOwnership {
    /// Prepares the metadata sent to `agent`: embeds the client capabilities, and narrows the client
    /// data model to the surfaces that agent owns.
    ///
    /// The narrowing is a security boundary, not a size optimization. It is what stops one agent
    /// from reading another agent's surface data — the official "Data Model Stripping to prevent
    /// data leakage". Send agent-bound metadata through this function and not around it; a message
    /// assembled by hand carries every surface in the conversation to whoever receives it.
    ///
    /// Stripping runs whenever a data model is present, including when the agent owns no surfaces
    /// at all, so an agent with an empty set receives an empty data model rather than the unfiltered
    /// one. That matches the official interceptor.
    ///
    /// - Returns: `nil` when the resulting metadata is empty, so the caller can leave
    ///   `Message.metadata` unset rather than sending an empty object.
    public func outboundMetadata(
        _ metadata: A2AMetadata?,
        capabilities: A2UIRendererCapabilities?,
        for agent: String
    ) throws -> A2AMetadata? {
        var result = metadata ?? [:]
        if let capabilities {
            try A2UIMessageMetadata.embed(capabilities, into: &result)
        }
        if let dataModel = A2UIMessageMetadata.rendererDataModel(in: result) {
            try A2UIMessageMetadata.embed(dataModel.keeping(surfaceIds(ownedBy: agent)), into: &result)
        }
        return result.isEmpty ? nil : result
    }
}

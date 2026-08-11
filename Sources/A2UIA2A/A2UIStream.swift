import A2ACore
import A2UICore

/// Helpers that pull A2UI server messages out of A2A parts and stream events, the equivalent of
/// the Python SDK's a2ui extraction.
///
/// This is the API an orchestrator uses to forward a worker's A2UI output to the renderer over a
/// side channel.
extension Sequence where Element == Part {
    /// Collects the A2UI server messages in this sequence of parts.
    ///
    /// Non-A2UI parts are skipped, and a part that claims A2UI but fails to decode is swallowed
    /// too — lenient by design, so one bad part cannot stop rendering or routing. Nothing
    /// distinguishes "no A2UI here" from "the A2UI was broken"; call `a2uiAgentMessage()` on the
    /// part directly when that difference matters.
    public func a2uiAgentMessages() -> [AgentMessage] {
        compactMap { try? $0.a2uiAgentMessage() }
    }

    /// `true` when any part is tagged A2UI, whether or not its payload decodes — pair it with
    /// `a2uiAgentMessages()` to detect parts that were dropped.
    public var containsA2UI: Bool {
        contains(where: \.isA2UI)
    }
}

extension StreamResponse {
    /// Collects the A2UI server messages carried by this stream event, as leniently as the
    /// `Sequence` version.
    public func a2uiAgentMessages() -> [AgentMessage] {
        parts.a2uiAgentMessages()
    }

    /// `true` when this stream event carries at least one A2UI-tagged part.
    public var containsA2UI: Bool {
        parts.containsA2UI
    }
}

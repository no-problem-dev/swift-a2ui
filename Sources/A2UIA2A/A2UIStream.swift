import A2ACore
import A2UICore

/// Helpers that pull A2UI server messages out of A2A parts and stream events, the equivalent of
/// the Python SDK's a2ui extraction.
///
/// This is the API an orchestrator uses to forward a worker's A2UI output to the renderer over a
/// side channel.
/// The A2UI found in a run of A2A parts, and what had to be thrown away to get it.
///
/// Extraction stays lenient — one bad part must not stop rendering or routing — but leniency and
/// silence are different things. An orchestrator forwarding a worker's output has to respond
/// differently to "this turn carried no UI" than to "this turn carried UI we could not read", and
/// the second is routine when an LLM agent wrote the payload.
public struct A2UIPartExtraction: Sendable, Equatable {
    /// Every A2UI message that decoded, in part order.
    public let messages: [AgentMessage]
    /// The decode failures of parts that were tagged A2UI, in part order. Non-empty means the
    /// sender meant to send UI and this side could not read it.
    public let failures: [String]

    public init(messages: [AgentMessage], failures: [String]) {
        self.messages = messages
        self.failures = failures
    }

    /// `true` when at least one A2UI-tagged part did not decode.
    public var hasFailures: Bool { !failures.isEmpty }
}

extension Sequence where Element == Part {
    /// Collects the A2UI server messages in this sequence of parts, alongside the tagged parts that
    /// would not decode.
    ///
    /// Non-A2UI parts are skipped without comment — they are not addressed to this layer. A part
    /// that claims A2UI and fails to decode is reported in `failures`, because dropping it silently
    /// makes a broken payload look exactly like a turn that simply had no UI in it.
    public func a2uiExtraction() -> A2UIPartExtraction {
        var messages: [AgentMessage] = []
        var failures: [String] = []
        for part in self where part.isA2UI {
            do {
                // Tagged A2UI but carrying no payload at all is a failure too, not an absence:
                // the sender said there was UI here.
                guard let message = try part.a2uiAgentMessage() else {
                    failures.append("A2UI part carried no data")
                    continue
                }
                messages.append(message)
            } catch {
                failures.append("\(error)")
            }
        }
        return A2UIPartExtraction(messages: messages, failures: failures)
    }

    /// `true` when any part is tagged A2UI, whether or not its payload decodes.
    public var containsA2UI: Bool {
        contains(where: \.isA2UI)
    }
}

extension StreamResponse {
    /// Collects the A2UI carried by this stream event, as leniently as the `Sequence` version and
    /// reporting the same failures.
    public func a2uiExtraction() -> A2UIPartExtraction {
        parts.a2uiExtraction()
    }

    /// `true` when this stream event carries at least one A2UI-tagged part.
    public var containsA2UI: Bool {
        parts.containsA2UI
    }
}

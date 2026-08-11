/// What a tool result carried, and — when it carried no UI — why.
///
/// "No messages" cannot be the whole answer. A caller has to respond differently to *this result
/// came from some other tool* (ignore it) than to *the UI tool answered and we could not read what
/// it said* (report it, retry, or fail loudly), and an LLM agent produces both routinely. Collapsing
/// the two into one empty result leaves the caller unable to tell a quiet turn from a broken one.
public enum A2UIToolPayload: Sendable, Equatable {
    /// The result came from a different tool, so no UI was ever expected in it.
    case otherTool
    /// The UI tool ran and reported an error. The model sees that error and corrects itself, so
    /// nothing here is forwarded to the client.
    case toolError
    /// The UI tool reported success, but its envelope did not decode. Something was sent and could
    /// not be read — the one case that used to be indistinguishable from silence.
    case unreadable
    /// The messages the result carried. An empty array means the tool genuinely sent none.
    case messages([AgentMessage])

    /// The messages, or `nil` for every case that carried none.
    ///
    /// For callers that really do treat all three failures alike. Reach for the cases themselves
    /// when the difference matters, which is most of the time.
    public var messages: [AgentMessage]? {
        if case .messages(let messages) = self { return messages }
        return nil
    }
}

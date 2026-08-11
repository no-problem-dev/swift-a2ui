/// The payload of `Action.event`: a named event for the host, plus the values the agent wants sent
/// along with it.
///
/// Each entry of `context` is resolved against the component's data scope before it leaves, so the
/// agent receives values rather than bindings. With `wantResponse` set the client waits for an
/// `actionResponse` before treating the action as finished, and writes what comes back into its
/// data model at `responsePath` when one is given.
public struct EventAction: Codable, Sendable, Equatable {
    public let name: String
    public let context: [String: DynamicValue]?
    /// `true` if the client should expect an `actionResponse` for this event.
    public let wantResponse: Bool?
    /// JSON Pointer the client writes the response value to. Optional; without it the response is
    /// delivered but never lands in the data model.
    public let responsePath: String?

    public init(
        name: String,
        context: [String: DynamicValue]? = nil,
        wantResponse: Bool? = nil,
        responsePath: String? = nil
    ) {
        self.name = name
        self.context = context
        self.wantResponse = wantResponse
        self.responsePath = responsePath
    }
}

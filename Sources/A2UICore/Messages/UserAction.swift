import StructuredDataCore
/// Reports that the user triggered an `Action.event` on a component — a tap, a submit, a selection
/// (A2UI v1.0).
///
/// `context` carries whatever the event declared, already resolved against the component's data
/// scope, so the agent reads values rather than bindings. When `wantResponse` is `true` the client
/// waits for an `actionResponse` and `actionId` is what pairs the two.
public struct UserAction: Codable, Sendable, Equatable {
    public let name: String
    public let surfaceId: String
    public let sourceComponentId: String
    public let timestamp: String  // ISO 8601
    public let context: [String: StructuredValue]
    /// `true` while the client is waiting for an `actionResponse` before it considers this done.
    public let wantResponse: Bool?
    /// Unique id for this invocation, required only when `wantResponse` is `true`.
    public let actionId: String?

    public init(
        name: String,
        surfaceId: String,
        sourceComponentId: String,
        timestamp: String,
        context: [String: StructuredValue],
        wantResponse: Bool? = nil,
        actionId: String? = nil
    ) {
        self.name = name
        self.surfaceId = surfaceId
        self.sourceComponentId = sourceComponentId
        self.timestamp = timestamp
        self.context = context
        self.wantResponse = wantResponse
        self.actionId = actionId
    }
}

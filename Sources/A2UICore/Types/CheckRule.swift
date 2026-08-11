/// A validation rule an input carries, evaluated by the client rather than the agent.
///
/// While `condition` resolves to false the renderer shows `message` as the component's validation
/// error and disables the `Button` that would submit it, so the agent never receives a value the
/// UI already declared invalid. `condition` is re-evaluated on every edit.
public struct CheckRule: Codable, Sendable, Equatable {
    public let condition: DynamicBoolean
    public let message: String

    public init(condition: DynamicBoolean, message: String) {
        self.condition = condition
        self.message = message
    }
}

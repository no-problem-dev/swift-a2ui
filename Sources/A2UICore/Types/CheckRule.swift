public struct CheckRule: Codable, Sendable, Equatable {
    public let condition: DynamicBoolean
    public let message: String

    public init(condition: DynamicBoolean, message: String) {
        self.condition = condition
        self.message = message
    }
}

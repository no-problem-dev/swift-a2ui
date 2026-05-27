public struct EventAction: Codable, Sendable, Equatable {
    public let name: String
    public let context: [String: DynamicValue]?

    public init(name: String, context: [String: DynamicValue]? = nil) {
        self.name = name
        self.context = context
    }
}

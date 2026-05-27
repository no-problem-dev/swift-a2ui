public struct DataBinding: Codable, Sendable, Equatable, Hashable {
    public let path: String

    public init(path: String) {
        self.path = path
    }
}

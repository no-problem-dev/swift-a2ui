/// A JSON Pointer reference into the surface data model (`path` follows RFC 6901).
public struct DataBinding: Codable, Sendable, Equatable, Hashable {
    public let path: String

    public init(path: String) {
        self.path = path
    }
}

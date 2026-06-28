/// サーフェスデータモデルへの JSON Pointer 参照（`path` は RFC 6901 に従う）。
public struct DataBinding: Codable, Sendable, Equatable, Hashable {
    public let path: String

    public init(path: String) {
        self.path = path
    }
}

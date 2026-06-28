/// 指定したサーフェスを破棄するようクライアントに指示する（A2UI v0.10）。
public struct DeleteSurface: Codable, Sendable, Equatable {
    public let surfaceId: String

    public init(surfaceId: String) {
        self.surfaceId = surfaceId
    }
}

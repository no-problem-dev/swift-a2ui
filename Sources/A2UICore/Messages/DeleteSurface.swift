/// 指定したサーフェスを破棄するようクライアントに指示する（A2UI v1.0）。
public struct DeleteSurface: Codable, Sendable, Equatable {
    public let surfaceId: String

    public init(surfaceId: String) {
        self.surfaceId = surfaceId
    }
}

/// クライアント → サーバのエラー（A2UI v0.10 `error`）。
///
/// `VALIDATION_FAILED` エラーはサーフェス（`surfaceId` + `path`）と対応付ける。汎用エラーは
/// `surfaceId`（サーフェススコープ）か `functionCallId`（失敗したサーバ起動の関数呼び出し）の
/// いずれか一方を持つ — ワイヤースキーマで強制されるが、Swift 型は両方オプション扱いにしている。
public struct ClientError: Codable, Sendable, Equatable {
    public let code: String
    public let message: String
    public let surfaceId: String?
    public let path: String?
    /// v0.10: 失敗したサーバ起動の関数呼び出しと対応付ける場合に設定する。
    public let functionCallId: CallId?

    public init(
        code: String,
        surfaceId: String? = nil,
        message: String,
        path: String? = nil,
        functionCallId: CallId? = nil
    ) {
        self.code = code
        self.message = message
        self.surfaceId = surfaceId
        self.path = path
        self.functionCallId = functionCallId
    }
}

/// A client→server error (A2UI v0.10 `error`).
///
/// `VALIDATION_FAILED` errors correlate to a surface (`surfaceId` + `path`). Generic errors must
/// carry exactly one of `surfaceId` (surface-scoped) or `functionCallId` (a failed server-initiated
/// function call) — enforced by the wire schema; the Swift type keeps both optional.
public struct ClientError: Codable, Sendable, Equatable {
    public let code: String
    public let message: String
    public let surfaceId: String?
    public let path: String?
    /// v0.10: set when this error correlates to a failed server-initiated function call.
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

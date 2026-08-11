/// What the client sends back when it cannot carry out what the agent asked (A2UI v1.0 `error`).
///
/// A `VALIDATION_FAILED` error points at the offending spot with `surfaceId` plus `path`. Every
/// other error carries exactly one of `surfaceId` (surface-scoped) or `functionCallId` (a function
/// call that failed). The wire schema enforces that either/or; this type does not, so a value with
/// both set encodes happily and is rejected on the far side.
public struct RendererError: Codable, Sendable, Equatable {
    public let code: String
    public let message: String
    public let surfaceId: String?
    public let path: String?
    /// Set this when the error answers a `CallFunctionMessage`, and leave `surfaceId` unset.
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

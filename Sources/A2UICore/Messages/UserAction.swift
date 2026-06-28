/// クライアントが送信するユーザーアクション（A2UI v0.10）。
///
/// `wantResponse` が `true` の場合、クライアントはサーバからの `actionResponse` を待つ。
/// その際 `actionId` でアクションを一意に識別する（`wantResponse: true` 時のみ必要）。
public struct UserAction: Codable, Sendable, Equatable {
    public let name: String
    public let surfaceId: String
    public let sourceComponentId: String
    public let timestamp: String  // ISO 8601
    public let context: [String: StructuredValue]
    /// v0.10: true の場合、クライアントはサーバから `actionResponse` を期待する。
    public let wantResponse: Bool?
    /// v0.10: このアクション呼び出しの一意 ID。`wantResponse: true` の場合のみ必要。
    public let actionId: String?

    public init(
        name: String,
        surfaceId: String,
        sourceComponentId: String,
        timestamp: String,
        context: [String: StructuredValue],
        wantResponse: Bool? = nil,
        actionId: String? = nil
    ) {
        self.name = name
        self.surfaceId = surfaceId
        self.sourceComponentId = sourceComponentId
        self.timestamp = timestamp
        self.context = context
        self.wantResponse = wantResponse
        self.actionId = actionId
    }
}

/// `Action.event` のペイロード: ホストへ送信する名前付きイベント。
///
/// `wantResponse: true` を設定すると、クライアントはサーバからの `actionResponse` を待つ。
/// `responsePath` が指定された場合、応答値をデータモデルのそのパスへ書き込む。
public struct EventAction: Codable, Sendable, Equatable {
    public let name: String
    public let context: [String: DynamicValue]?
    /// v0.10: true の場合、クライアントはサーバから `actionResponse` を期待する。
    public let wantResponse: Bool?
    /// v0.10: クライアントがデータモデルへ応答値を書き込む JSON Pointer パス（オプション）。
    public let responsePath: String?

    public init(
        name: String,
        context: [String: DynamicValue]? = nil,
        wantResponse: Bool? = nil,
        responsePath: String? = nil
    ) {
        self.name = name
        self.context = context
        self.wantResponse = wantResponse
        self.responsePath = responsePath
    }
}

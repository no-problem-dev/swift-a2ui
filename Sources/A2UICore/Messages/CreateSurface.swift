/// サーフェスの初期作成を指示するサーバ → クライアントメッセージ（A2UI v0.10）。
///
/// `components` と `dataModel` は初回描画用のオプション項目で、直後の `updateComponents` /
/// `updateDataModel` と等価に処理される。データモデルを先に適用することで、
/// ルートコンポーネントが現れた時点でバインディングが解決される。
public struct CreateSurface: Codable, Sendable, Equatable {
    public let surfaceId: String
    public let catalogId: String
    public let theme: StructuredValue?
    public let sendDataModel: Bool?
    /// v0.10: オプションの初期コンポーネントリスト（アトミックな初回描画）。`updateComponents.components` と同形式。
    public let components: [StructuredValue]?
    /// v0.10: オプションの初期ルートデータモデルオブジェクト。
    public let dataModel: StructuredValue?

    public init(
        surfaceId: String,
        catalogId: String,
        theme: StructuredValue? = nil,
        sendDataModel: Bool? = nil,
        components: [StructuredValue]? = nil,
        dataModel: StructuredValue? = nil
    ) {
        self.surfaceId = surfaceId
        self.catalogId = catalogId
        self.theme = theme
        self.sendDataModel = sendDataModel
        self.components = components
        self.dataModel = dataModel
    }
}

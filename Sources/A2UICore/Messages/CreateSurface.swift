/// サーフェスの初期作成を指示するエージェント → レンダラメッセージ（A2UI v1.0）。
///
/// `components` と `dataModel` は初回描画用のオプション項目で、直後の `updateComponents` /
/// `updateDataModel` と等価に処理される。データモデルを先に適用することで、
/// ルートコンポーネントが現れた時点でバインディングが解決される。
///
/// `surfaceId` はレンダラの生存期間で**グローバルに一意**でなければならない。既存 ID に対して
/// 削除なしで再作成するのは仕様上のエラー。
public struct CreateSurface: Codable, Sendable, Equatable {
    public let surfaceId: String
    /// v1.0: サーフェス既定のカタログ。**任意**。個々のコンポーネント／関数呼び出しが
    /// `catalogId` を明示しない場合にこれが使われる（→ `ComponentCommon.catalogId`）。
    public let catalogId: String?
    public let sendDataModel: Bool?
    /// v1.0: オプションの初期コンポーネントリスト（アトミックな初回描画）。`updateComponents.components` と同形式。
    public let components: [StructuredValue]?
    /// v1.0: オプションの初期ルートデータモデルオブジェクト。
    public let dataModel: StructuredValue?

    public init(
        surfaceId: String,
        catalogId: String? = nil,
        sendDataModel: Bool? = nil,
        components: [StructuredValue]? = nil,
        dataModel: StructuredValue? = nil
    ) {
        self.surfaceId = surfaceId
        self.catalogId = catalogId
        self.sendDataModel = sendDataModel
        self.components = components
        self.dataModel = dataModel
    }
}

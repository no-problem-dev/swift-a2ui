import StructuredDataCore
/// JSON Pointer `path` が指すサーフェスデータモデルの位置に `value` を書き込む（A2UI v1.0）。
///
/// v1.0 で `value` は**必須**になった。キーを削除するときは `value` を明示的に `.null` にする
/// （省略はスキーマ検証エラー）。`path` の省略／`"/"` はデータモデル全体を指す。
public struct UpdateDataModel: Codable, Sendable, Equatable {
    public let surfaceId: String
    public let path: String?
    /// 書き込む値。`.null` は「`path` のキーを削除する」を意味する。
    public let value: StructuredValue

    public init(
        surfaceId: String,
        path: String? = nil,
        value: StructuredValue
    ) {
        self.surfaceId = surfaceId
        self.path = path
        self.value = value
    }
}

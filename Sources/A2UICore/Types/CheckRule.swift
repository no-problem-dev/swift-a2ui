/// コンポーネントに付与する入力検証ルール。
///
/// `condition` が false に評価されると `message` を検証エラーとして表示し、
/// そのコンポーネントが属する `Button` を無効化する。
public struct CheckRule: Codable, Sendable, Equatable {
    public let condition: DynamicBoolean
    public let message: String

    public init(condition: DynamicBoolean, message: String) {
        self.condition = condition
        self.message = message
    }
}

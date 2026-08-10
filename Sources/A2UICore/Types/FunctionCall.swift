import StructuredDataCore
/// 関数の呼び出し元制約（A2UI v1.0 `callableFrom`）。
///
/// v1.0 では**ワイヤ上の `FunctionCall` には載らない** — カタログの `FunctionDefinition` が持つ
/// 静的メタデータであり、境界チェックは実行時にカタログを引いて行う。
public enum CallableFrom: String, Codable, Sendable, Equatable {
    case rendererOnly
    case agentOnly
    case rendererOrAgent
}

/// レンダラ側関数またはエージェント起動関数の呼び出し仕様（A2UI v1.0）。
///
/// `call` は関数名、`args` は文字列キーの引数マップ。v1.0 で `callableFrom` / `returnType` は
/// ワイヤ形式から外れ、カタログの `FunctionDefinition` 側の静的メタデータになった。
public struct FunctionCall: Codable, Sendable, Equatable {
    public let call: String
    /// v1.0: この関数のカタログ ID。サーフェス既定の `catalogId` を上書きする。
    public let catalogId: String?
    public let args: [String: StructuredValue]?

    public init(
        call: String,
        catalogId: String? = nil,
        args: [String: StructuredValue]? = nil
    ) {
        self.call = call
        self.catalogId = catalogId
        self.args = args
    }
}

extension FunctionCall {
    /// 組み込み `@index` 関数の名前。`@` プレフィックスはコアのシステム評価用に予約されている。
    public static let indexFunctionName = "@index"

    /// テンプレート反復中の 0 始まりの添字を返す組み込み `@index` 呼び出しを作る。
    ///
    /// - Parameter offset: 添字に加算する値（1 を渡すと 1 始まりになる）。既定は 0。
    public static func index(offset: Int? = nil) -> FunctionCall {
        FunctionCall(
            call: indexFunctionName,
            args: offset.map { ["offset": StructuredValue(integerLiteral: $0)] }
        )
    }

    /// `@` で始まる名前（コア予約のシステム評価）かどうか。
    public var isSystemFunction: Bool { call.hasPrefix("@") }
}

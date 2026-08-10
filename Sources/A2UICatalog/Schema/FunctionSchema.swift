import StructuredDataCore
import A2UICore

/// カタログ関数の仕様をタイプセーフに記述する型（仕様 §7 functions ブロック）。
public struct FunctionSchema: Sendable, Equatable {
    public let name: String
    public let description: String?
    public let arguments: [PropertySchema]
    /// `arguments` を上書きする生の `args` オブジェクト（設定時）。公式カタログの非定型な
    /// 引数形状（`anyOf`、`additionalProperties`、`$ref`+description 等）を正確に再現するために使用する。
    public let argsObject: StructuredValue?
    /// 戻り値型の定数文字列（例: "string" / "number" / "boolean" / "void" など）。
    ///
    /// v1.0 ではワイヤ上の `FunctionCall` から外れ、カタログ側の静的メタデータになった。
    public let returnType: String
    /// v1.0: この関数を呼び出せる場所（`rendererOnly` / `agentOnly` / `rendererOrAgent`）。
    /// 省略時は `rendererOnly` 扱い。実行時にカタログを引いて境界を検証する。
    public let callableFrom: String?

    public init(
        name: String,
        description: String? = nil,
        arguments: [PropertySchema] = [],
        argsObject: StructuredValue? = nil,
        returnType: String,
        callableFrom: String? = nil
    ) {
        self.name = name
        self.description = description
        self.arguments = arguments
        self.argsObject = argsObject
        self.returnType = returnType
        self.callableFrom = callableFrom
    }
}

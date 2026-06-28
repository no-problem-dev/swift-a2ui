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
    public let returnType: String

    public init(
        name: String,
        description: String? = nil,
        arguments: [PropertySchema] = [],
        argsObject: StructuredValue? = nil,
        returnType: String
    ) {
        self.name = name
        self.description = description
        self.arguments = arguments
        self.argsObject = argsObject
        self.returnType = returnType
    }
}

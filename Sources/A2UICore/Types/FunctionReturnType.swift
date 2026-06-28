/// 関数の戻り値型（A2UI v0.10 `returnType`）。
public enum FunctionReturnType: String, Codable, Sendable, Equatable, Hashable {
    case string
    case number
    case boolean
    case array
    case object
    case void
}

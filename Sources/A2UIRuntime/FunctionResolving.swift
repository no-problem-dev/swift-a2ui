import A2UICore

/// 動的値の解決中に `FunctionCall` を評価するフック。
///
/// 実際の関数レジストリ（Basic Catalog 関数: `formatString`、`required` など）はステップ 3 で
/// 実装する。`DataContext` はこのプロトコルのみに依存し、ステップ 2（バインド解決）と
/// ステップ 3（関数）を疎結合に保つ。
public protocol FunctionResolving: Sendable {
    /// 指定のデータコンテキスト内で関数呼び出しを評価し、結果（または nil）を返す。
    func evaluate(_ call: FunctionCall, in context: DataContext) -> StructuredValue?
}

/// 何もしないリゾルバ: あらゆる関数呼び出しを nil に解決する。
/// Basic Catalog 関数レジストリが注入されるステップ 3 まで、デフォルトとして使用する。
public struct NoFunctionResolver: FunctionResolving {
    public init() {}
    public func evaluate(_ call: FunctionCall, in context: DataContext) -> StructuredValue? { nil }
}

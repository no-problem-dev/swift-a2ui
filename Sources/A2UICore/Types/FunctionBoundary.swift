/// エージェント起動の関数呼び出しに対する実行境界の検証（A2UI v1.0 §Processing rules）。
///
/// v1.0 は `callableFrom` / `returnType` をワイヤーから外し、**実行時にカタログを引いて**検証する
/// 方式にした。レンダラは `callFunction` を受け取ったら:
///
/// 1. 関数名をアクティブなカタログのレジストリで引く
/// 2. `callableFrom` が `rendererOnly`、または**未登録**なら、呼び出しを拒否して
///    `error { code: "INVALID_FUNCTION_CALL" }` を返す
///
/// `callableFrom` が省略されているカタログ関数は `rendererOnly` 既定。
public enum FunctionBoundary {

    /// 仕様が定めるエラーコード。
    public static let invalidFunctionCallCode = "INVALID_FUNCTION_CALL"

    /// エージェントからの呼び出しを受理してよいか判定する。
    ///
    /// - Parameters:
    ///   - name: 呼び出された関数名。
    ///   - callableFrom: カタログの `FunctionDefinition.callableFrom`。未登録なら `nil` を渡す。
    ///     省略されている登録済み関数には `.rendererOnly`（既定）を渡す。
    public static func acceptsAgentCall(name: String, callableFrom: CallableFrom?) -> Bool {
        switch callableFrom {
        case .agentOnly, .rendererOrAgent: true
        // rendererOnly、または未登録（nil）は拒否する。
        case .rendererOnly, nil: false
        }
    }

    /// 拒否時に返す `error` メッセージを組み立てる。
    ///
    /// - Parameters:
    ///   - functionCallId: 拒否する `callFunction` の ID（相関のため必ず載せる）。
    ///   - name: 呼び出された関数名。
    ///   - registered: カタログに登録されていたか（メッセージの文言が変わる）。
    public static func rejection(
        functionCallId: CallId,
        name: String,
        registered: Bool
    ) -> RendererError {
        let reason = registered
            ? "is rendererOnly and cannot be invoked remotely"
            : "is not registered in the active catalog"
        return RendererError(
            code: invalidFunctionCallCode,
            message: "Function '\(name)' \(reason).",
            functionCallId: functionCallId
        )
    }

    /// 呼び出しを検証し、拒否すべきなら返すべき `error` を返す。受理できるなら `nil`。
    public static func validateAgentCall(
        _ message: CallFunctionMessage,
        callableFrom: CallableFrom?
    ) -> RendererError? {
        let name = message.callFunction.call
        guard !acceptsAgentCall(name: name, callableFrom: callableFrom) else { return nil }
        return rejection(
            functionCallId: message.functionCallId,
            name: name,
            registered: callableFrom != nil
        )
    }
}

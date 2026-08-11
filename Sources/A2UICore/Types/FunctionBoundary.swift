/// Decides whether an agent is allowed to invoke a given function (A2UI v1.0 §Processing rules).
///
/// Permission is not on the wire, so the renderer has to establish it itself. On receiving a
/// `callFunction` it:
///
/// 1. looks the function name up in the active catalog's registry
/// 2. rejects the call with `error { code: "INVALID_FUNCTION_CALL" }` when `callableFrom` is
///    `rendererOnly` or when the name is not registered at all
///
/// A catalog function that omits `callableFrom` is `rendererOnly` by default, so forgetting to
/// declare it means agents cannot call it.
public enum FunctionBoundary {

    /// The code the specification requires on a rejection; agents match on it.
    public static let invalidFunctionCallCode = "INVALID_FUNCTION_CALL"

    /// Returns whether a call arriving from the agent may run.
    ///
    /// - Parameters:
    ///   - name: The function that was called.
    ///   - callableFrom: The catalog's `FunctionDefinition.callableFrom`. Pass `nil` when the name
    ///     is not registered, and `.rendererOnly` — the default — for a registered function that
    ///     omits it.
    public static func acceptsAgentCall(name: String, callableFrom: CallableFrom?) -> Bool {
        switch callableFrom {
        case .agentOnly, .rendererOrAgent: true
        // rendererOnly, and an unregistered name (nil), are both refused.
        case .rendererOnly, nil: false
        }
    }

    /// Builds the `error` to send back for a refused call.
    ///
    /// - Parameters:
    ///   - functionCallId: Id of the `callFunction` being refused; always carry it, or the agent
    ///     cannot tell which call failed.
    ///   - name: The function that was called.
    ///   - registered: Whether the catalog knows the name — it changes the wording so the agent can
    ///     tell a typo from a permission problem.
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

    /// Checks a call and returns the `error` to send back, or `nil` when it may run — the one entry
    /// point a renderer needs before dispatching a `callFunction`.
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

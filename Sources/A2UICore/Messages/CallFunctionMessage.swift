import StructuredDataCore
/// An agent asking the renderer to run a catalog function on its behalf (A2UI v1.0).
///
/// Copy `functionCallId` verbatim into the resulting `FunctionResponse` (or `error`); it is the
/// only thing that pairs a reply with its call.
///
/// Permission does not travel on the wire. The renderer looks the name up in the active catalog and
/// reads `FunctionDefinition.callableFrom` (`agentOnly` / `rendererOrAgent`), rejecting
/// `rendererOnly` and unregistered names with `INVALID_FUNCTION_CALL` — see `FunctionBoundary`.
///
/// These fields are siblings of `version` at the top level of the message, not nested under a key.
public struct CallFunctionMessage: Codable, Sendable, Equatable {
    public let functionCallId: CallId
    public let wantResponse: Bool?
    public let callFunction: FunctionCall

    public init(functionCallId: CallId, callFunction: FunctionCall, wantResponse: Bool? = nil) {
        self.functionCallId = functionCallId
        self.callFunction = callFunction
        self.wantResponse = wantResponse
    }
}

/// The agent's reply to a client action that asked for one with `wantResponse: true` (A2UI v1.0).
///
/// `actionId` must match the id the originating action carried. When that action also carried a
/// `responsePath`, the client writes the returned value into its own data model at that pointer.
/// These fields are siblings of `version` at the top level of the message.
public struct ActionResponseMessage: Codable, Sendable, Equatable {
    public let actionId: String
    public let actionResponse: ActionResponse

    public init(actionId: String, actionResponse: ActionResponse) {
        self.actionId = actionId
        self.actionResponse = actionResponse
    }
}

/// The payload of an `ActionResponseMessage`: either the returned `value` or an `error` explaining
/// why the agent could not produce one.
///
/// Decoding keys off the presence of `error`, so a payload carrying both reads as the error.
public enum ActionResponse: Sendable, Equatable {
    case value(StructuredValue)
    case error(code: String, message: String)
}

extension ActionResponse: Codable {
    private enum CodingKeys: String, CodingKey { case value, error }
    private struct ErrorBody: Codable, Equatable { let code: String; let message: String }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if container.contains(.error) {
            let body = try container.decode(ErrorBody.self, forKey: .error)
            self = .error(code: body.code, message: body.message)
        } else {
            self = .value(try container.decode(StructuredValue.self, forKey: .value))
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .value(let v):
            try container.encode(v, forKey: .value)
        case .error(let code, let message):
            try container.encode(ErrorBody(code: code, message: message), forKey: .error)
        }
    }
}

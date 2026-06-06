/// Server→client request to invoke a function on the client (A2UI v0.10).
///
/// The `functionCallId` MUST be copied verbatim into the matching `FunctionResponse` (or `error`).
/// `callFunction.callableFrom` is `remoteOnly` or `clientOrRemote` (a server cannot invoke a
/// `clientOnly` function). On the wire these fields sit alongside `version` at the message top level.
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

/// Server→client response to a client action that set `wantResponse: true` (A2UI v0.10).
///
/// `actionId` correlates the response to the originating `action`. The client writes the value into
/// its local data model at the action's `responsePath` (if any). Sits alongside `version` on the wire.
public struct ActionResponseMessage: Codable, Sendable, Equatable {
    public let actionId: String
    public let actionResponse: ActionResponse

    public init(actionId: String, actionResponse: ActionResponse) {
        self.actionId = actionId
        self.actionResponse = actionResponse
    }
}

/// The payload of an `ActionResponseMessage`: either a return `value` or an `error`.
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

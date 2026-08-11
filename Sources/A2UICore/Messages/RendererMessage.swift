/// Everything a client can say back to the agent, in one decodable envelope (A2UI v1.0).
///
/// Unlike `AgentMessage`, decoding requires `version` and throws when it is absent or differs from
/// `A2UIVersion.current`: this side of the conversation is written by code, so a missing field is a
/// defect rather than a model slip worth tolerating.
public enum RendererMessage: Sendable, Equatable {
    case action(UserAction)
    case error(RendererError)
    /// Returns the result of a function the agent asked the client to run.
    case functionResponse(FunctionResponse)
}

extension RendererMessage: Codable {
    private enum CodingKeys: String, CodingKey {
        case version
        case action
        case error
        case functionResponse
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let version = try container.decode(String.self, forKey: .version)
        guard version == A2UIVersion.current else {
            throw DecodingError.dataCorruptedError(
                forKey: .version, in: container,
                debugDescription: "Unsupported A2UI version: \(version)"
            )
        }
        if container.contains(.action) {
            self = .action(try container.decode(UserAction.self, forKey: .action))
        } else if container.contains(.functionResponse) {
            self = .functionResponse(try container.decode(FunctionResponse.self, forKey: .functionResponse))
        } else if container.contains(.error) {
            self = .error(try container.decode(RendererError.self, forKey: .error))
        } else {
            throw DecodingError.dataCorrupted(
                DecodingError.Context(
                    codingPath: container.codingPath,
                    debugDescription: "No recognized message type key found"
                )
            )
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(A2UIVersion.current, forKey: .version)
        switch self {
        case .action(let msg):
            try container.encode(msg, forKey: .action)
        case .functionResponse(let msg):
            try container.encode(msg, forKey: .functionResponse)
        case .error(let msg):
            try container.encode(msg, forKey: .error)
        }
    }
}

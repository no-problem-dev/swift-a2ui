public enum ClientMessage: Sendable, Equatable {
    case action(UserAction)
    case error(ClientError)
}

extension ClientMessage: Codable {
    private enum CodingKeys: String, CodingKey {
        case version
        case action
        case error
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
        } else if container.contains(.error) {
            self = .error(try container.decode(ClientError.self, forKey: .error))
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
        case .error(let msg):
            try container.encode(msg, forKey: .error)
        }
    }
}

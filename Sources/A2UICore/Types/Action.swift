/// A UI action: either a named event dispatched to the host or a server-side function call.
public enum Action: Sendable, Equatable {
    case event(EventAction)
    case functionCall(FunctionCall)
}

// MARK: - Codable

extension Action: Codable {
    public init(from decoder: Decoder) throws {
        let keyed = try decoder.container(keyedBy: CodingKeys.self)
        if keyed.allKeys.contains(.event) {
            self = .event(try keyed.decode(EventAction.self, forKey: .event))
        } else if keyed.allKeys.contains(.functionCall) {
            self = .functionCall(try keyed.decode(FunctionCall.self, forKey: .functionCall))
        } else {
            throw DecodingError.dataCorruptedError(
                forKey: .event,
                in: keyed,
                debugDescription: "Cannot decode Action: expected 'event' or 'functionCall' key"
            )
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .event(let value):
            try container.encode(value, forKey: .event)
        case .functionCall(let value):
            try container.encode(value, forKey: .functionCall)
        }
    }

    private enum CodingKeys: String, CodingKey {
        case event, functionCall
    }
}

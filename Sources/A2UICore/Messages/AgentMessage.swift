/// Everything an agent can say to a client, in one decodable envelope (A2UI v1.0).
///
/// Decoding follows Postel's law on `version`: a missing field is assumed to be the current
/// version, because these payloads are written by a model and dropping a whole turn over a
/// misplaced key costs a full regeneration. A version that is present and different is still
/// rejected — that is a real incompatibility, not a formatting slip.
public enum AgentMessage: Sendable, Equatable {
    case createSurface(CreateSurface)
    case updateComponents(UpdateComponents)
    case updateDataModel(UpdateDataModel)
    case deleteSurface(DeleteSurface)
    /// Asks the client to run one of its own functions and, if requested, report the result back.
    case callFunction(CallFunctionMessage)
    /// Answers a client action that was sent with `wantResponse: true`.
    case actionResponse(ActionResponseMessage)
}

extension AgentMessage: Codable {
    private enum CodingKeys: String, CodingKey {
        case version
        case createSurface
        case updateComponents
        case updateDataModel
        case deleteSurface
        case callFunction
        case actionResponse
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        // Postel: encode always writes `version`; decode tolerates a missing one (assume current).
        // LLMs occasionally misplace `version` inside the payload — dropping the whole message for
        // that (and failing the turn as "no surface produced") costs a full regeneration round-trip.
        // A present-but-different version is still rejected: that is a genuine incompatibility.
        if let version = try container.decodeIfPresent(String.self, forKey: .version),
           version != A2UIVersion.current {
            throw DecodingError.dataCorruptedError(
                forKey: .version, in: container,
                debugDescription: "Unsupported A2UI version: \(version)"
            )
        }
        if container.contains(.createSurface) {
            self = .createSurface(try container.decode(CreateSurface.self, forKey: .createSurface))
        } else if container.contains(.updateComponents) {
            self = .updateComponents(try container.decode(UpdateComponents.self, forKey: .updateComponents))
        } else if container.contains(.updateDataModel) {
            self = .updateDataModel(try container.decode(UpdateDataModel.self, forKey: .updateDataModel))
        } else if container.contains(.deleteSurface) {
            self = .deleteSurface(try container.decode(DeleteSurface.self, forKey: .deleteSurface))
        } else if container.contains(.callFunction) {
            // Flat message: functionCallId / wantResponse / callFunction are siblings of `version`.
            self = .callFunction(try CallFunctionMessage(from: decoder))
        } else if container.contains(.actionResponse) {
            // Flat message: actionId / actionResponse are siblings of `version`.
            self = .actionResponse(try ActionResponseMessage(from: decoder))
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
        case .createSurface(let msg):
            try container.encode(msg, forKey: .createSurface)
        case .updateComponents(let msg):
            try container.encode(msg, forKey: .updateComponents)
        case .updateDataModel(let msg):
            try container.encode(msg, forKey: .updateDataModel)
        case .deleteSurface(let msg):
            try container.encode(msg, forKey: .deleteSurface)
        case .callFunction(let msg):
            // Flat: write functionCallId / wantResponse / callFunction alongside `version`.
            try msg.encode(to: encoder)
        case .actionResponse(let msg):
            try msg.encode(to: encoder)
        }
    }
}

extension AgentMessage {
    /// The `$defs` name this case carries in `agent_to_renderer.json` (for example
    /// `"CreateSurfaceMessage"`).
    ///
    /// `A2UIPromptBuilder(allowedMessages:)` prunes the schema by these names and post-generation
    /// validation checks against the same set, so what a prompt offers the model and what the
    /// validator accepts cannot drift apart.
    public var schemaMessageName: String {
        switch self {
        case .createSurface: "CreateSurfaceMessage"
        case .updateComponents: "UpdateComponentsMessage"
        case .updateDataModel: "UpdateDataModelMessage"
        case .deleteSurface: "DeleteSurfaceMessage"
        case .callFunction: "CallFunctionMessage"
        case .actionResponse: "ActionResponseMessage"
        }
    }
}

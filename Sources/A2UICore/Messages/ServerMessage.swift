public enum ServerMessage: Sendable, Equatable {
    case createSurface(CreateSurface)
    case updateComponents(UpdateComponents)
    case updateDataModel(UpdateDataModel)
    case deleteSurface(DeleteSurface)
}

extension ServerMessage: Codable {
    private enum CodingKeys: String, CodingKey {
        case version
        case createSurface
        case updateComponents
        case updateDataModel
        case deleteSurface
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
        if container.contains(.createSurface) {
            self = .createSurface(try container.decode(CreateSurface.self, forKey: .createSurface))
        } else if container.contains(.updateComponents) {
            self = .updateComponents(try container.decode(UpdateComponents.self, forKey: .updateComponents))
        } else if container.contains(.updateDataModel) {
            self = .updateDataModel(try container.decode(UpdateDataModel.self, forKey: .updateDataModel))
        } else if container.contains(.deleteSurface) {
            self = .deleteSurface(try container.decode(DeleteSurface.self, forKey: .deleteSurface))
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
        }
    }
}

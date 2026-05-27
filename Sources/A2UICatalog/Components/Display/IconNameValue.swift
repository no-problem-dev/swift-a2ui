import A2UICore

public enum IconNameValue: Codable, Sendable, Equatable {
    case preset(IconName)
    case svgPath(String)
    case binding(DataBinding)

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if let str = try? container.decode(String.self) {
            if let preset = IconName(rawValue: str) {
                self = .preset(preset)
            } else {
                self = .svgPath(str)
            }
            return
        }

        let keyed = try decoder.container(keyedBy: CodingKeys.self)
        if keyed.allKeys.contains(.svgPath) {
            self = .svgPath(try keyed.decode(String.self, forKey: .svgPath))
        } else if keyed.allKeys.contains(.path) {
            self = .binding(try DataBinding(from: decoder))
        } else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Cannot decode IconNameValue"
            )
        }
    }

    public func encode(to encoder: Encoder) throws {
        switch self {
        case .preset(let value):
            var container = encoder.singleValueContainer()
            try container.encode(value.rawValue)
        case .svgPath(let value):
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(value, forKey: .svgPath)
        case .binding(let value):
            try value.encode(to: encoder)
        }
    }

    private enum CodingKeys: String, CodingKey {
        case svgPath, path
    }
}

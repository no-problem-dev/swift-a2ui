import A2UICore

/// An Icon's `name` (A2UI v0.10): either a preset icon, or a custom SVG path object `{ "path": "…" }`.
///
/// v0.10 removed the `DataBinding` branch from the Icon `name` oneOf and renamed the custom-icon key
/// from `svgPath` to `path`, so `{ "path": "…" }` is now an unambiguous inline SVG path.
public enum IconNameValue: Codable, Sendable, Equatable {
    case preset(IconName)
    case svgPath(String)

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
        if keyed.allKeys.contains(.path) {
            self = .svgPath(try keyed.decode(String.self, forKey: .path))
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
            try container.encode(value, forKey: .path)
        }
    }

    private enum CodingKeys: String, CodingKey {
        case path
    }
}

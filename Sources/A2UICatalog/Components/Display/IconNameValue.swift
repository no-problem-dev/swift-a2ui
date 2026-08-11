import A2UICore

/// The value of `Icon.name` (A2UI v1.0), whose official `oneOf` has three branches:
///
/// 1. A preset icon name (string enum)
/// 2. A custom SVG, `{ "svgPath": <DynamicString> }`
/// 3. A data binding, `{ "path": "…" }`
///
/// The official samples swap a preset name through a binding — `06_music-player` binds
/// `{"path": "/playIcon"}` and writes `"pause"` into it. A string outside the preset set is kept as
/// `raw` rather than rejected: the official lit renderer forwards it straight to the Material
/// Symbols font, so it has to survive a round trip even where SF Symbols cannot draw it.
public enum IconNameValue: Codable, Sendable, Equatable {
    case preset(IconName)
    case binding(DataBinding)
    /// A custom SVG path. v1.0 types it as `DynamicString`, so a binding or a function call can
    /// appear here too.
    case svgPath(DynamicString)
    case raw(String)

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if let str = try? container.decode(String.self) {
            if let preset = IconName(rawValue: str) {
                self = .preset(preset)
            } else {
                self = .raw(str)
            }
            return
        }

        let keyed = try decoder.container(keyedBy: CodingKeys.self)
        if keyed.allKeys.contains(.svgPath) {
            self = .svgPath(try keyed.decode(DynamicString.self, forKey: .svgPath))
        } else if keyed.allKeys.contains(.path) {
            self = .binding(DataBinding(path: try keyed.decode(String.self, forKey: .path)))
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
        case .raw(let value):
            var container = encoder.singleValueContainer()
            try container.encode(value)
        case .binding(let value):
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(value.path, forKey: .path)
        case .svgPath(let value):
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(value, forKey: .svgPath)
        }
    }

    private enum CodingKeys: String, CodingKey {
        case path
        case svgPath
    }
}

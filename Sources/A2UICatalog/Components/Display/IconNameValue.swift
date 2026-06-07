import A2UICore

/// An Icon's `name` (A2UI v0.10): either a preset icon, or a data binding `{ "path": "…" }`.
///
/// v0.10 removed the v0.9 custom-SVG branch (`{ "svgPath": "…" }`) from the Icon `name` oneOf.
/// The remaining `{ "path": "…" }` object is the standard data binding — official examples bind
/// preset names through it (e.g. 06_music-player's `{"path": "/playIcon"}` → `"pause"`).
/// Non-preset strings stay first-class (`raw`): the official lit renderer forwards them to the
/// Material Symbols font verbatim, so they must round-trip even though SF Symbols can't show them.
public enum IconNameValue: Codable, Sendable, Equatable {
    case preset(IconName)
    case binding(DataBinding)
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
        if keyed.allKeys.contains(.path) {
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
        }
    }

    private enum CodingKeys: String, CodingKey {
        case path
    }
}

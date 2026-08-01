import A2UICore

/// Icon の `name` 値（A2UI v1.0）。公式カタログの `oneOf` は 3 分岐:
///
/// 1. プリセットアイコン名（文字列 enum）
/// 2. カスタム SVG `{ "svgPath": <DynamicString> }`
/// 3. データバインディング `{ "path": "…" }`
///
/// 公式サンプル（例: 06_music-player の `{"path": "/playIcon"}` → `"pause"`）はバインディング経由で
/// プリセット名を差し替える。プリセット以外の文字列は `raw` として保持する: 公式 lit レンダラーが
/// Material Symbols フォントへそのまま転送するため、SF Symbols で表示できなくても往復可能でなければならない。
public enum IconNameValue: Codable, Sendable, Equatable {
    case preset(IconName)
    case binding(DataBinding)
    /// カスタム SVG パス。v1.0 では `DynamicString` なのでバインディングや関数呼び出しも入りうる。
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

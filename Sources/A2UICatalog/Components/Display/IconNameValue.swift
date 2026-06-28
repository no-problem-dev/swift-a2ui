import A2UICore

/// Icon の `name` 値（A2UI v0.10）: プリセットアイコン名またはデータバインディング `{ "path": "…" }`。
///
/// v0.10 では v0.9 のカスタム SVG ブランチ（`{ "svgPath": "…" }`）が Icon の `name` oneOf から削除された。
/// 残る `{ "path": "…" }` は標準のデータバインディング。公式サンプル（例: 06_music-player の
/// `{"path": "/playIcon"}` → `"pause"`）もこれを通じてプリセット名をバインドする。
/// プリセット以外の文字列は `raw` として保持される: 公式 lit レンダラーが Material Symbols フォントへ
/// そのまま転送するため、SF Symbols で表示できなくても往復可能でなければならない。
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

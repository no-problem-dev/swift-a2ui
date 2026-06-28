import A2UICore

/// 画像サイズ・用途のヒント。レンダラーが表示サイズを決定するために使用する。
public enum ImageVariant: String, Codable, Sendable, Equatable, CaseIterable {
    case icon
    case avatar
    case smallFeature
    case mediumFeature
    case largeFeature
    case header
}

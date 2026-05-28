import A2UICore

public enum ImageVariant: String, Codable, Sendable, Equatable, CaseIterable {
    case icon
    case avatar
    case smallFeature
    case mediumFeature
    case largeFeature
    case header
}

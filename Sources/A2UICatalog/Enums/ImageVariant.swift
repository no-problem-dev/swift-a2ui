import A2UICore

/// Size and role hint a renderer maps to concrete dimensions, from `icon` up to a full-width
/// `header`. The catalog carries no width or height, so this is the only size control an agent
/// has; the schema defaults to `mediumFeature`.
public enum ImageVariant: String, Codable, Sendable, Equatable, CaseIterable {
    case icon
    case avatar
    case smallFeature
    case mediumFeature
    case largeFeature
    case header
}

import A2UICore

public enum ImageFit: String, Codable, Sendable, Equatable, CaseIterable {
    case contain
    case cover
    case fill
    case none
    case scaleDown
}

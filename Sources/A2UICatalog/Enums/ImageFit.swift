import A2UICore

/// How an image is resized inside its container, matching the CSS `object-fit` values. The schema
/// defaults to `fill`, which distorts an image whose aspect ratio differs from the box; `contain`
/// and `cover` preserve it.
public enum ImageFit: String, Codable, Sendable, Equatable, CaseIterable {
    case contain
    case cover
    case fill
    case none
    case scaleDown
}

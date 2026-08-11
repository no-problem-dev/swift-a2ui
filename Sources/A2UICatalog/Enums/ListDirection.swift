import A2UICore

/// Direction a `List` lays its children out, `vertical` by default.
///
/// `horizontal` produces a side-by-side strip, like the image carousel in the catalog's own
/// template example.
public enum ListDirection: String, Codable, Sendable, Equatable, CaseIterable {
    case vertical
    case horizontal
}

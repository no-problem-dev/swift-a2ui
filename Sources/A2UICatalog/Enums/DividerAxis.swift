import A2UICore

/// Orientation of a `Divider`: `horizontal` separates the stacked children of a `Column`,
/// `vertical` separates the side-by-side children of a `Row`.
public enum DividerAxis: String, Codable, Sendable, Equatable, CaseIterable {
    case horizontal
    case vertical
}

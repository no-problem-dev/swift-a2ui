import A2UICore

/// Alignment of children across the cross axis, as with CSS `align-items` but spelled in
/// camelCase. The schema defaults to `stretch`, so children fill the cross axis until told
/// otherwise.
public enum LayoutAlign: String, Codable, Sendable, Equatable, CaseIterable {
    case start
    case center
    case end
    case stretch
}

import A2UICore

/// Distribution of children along the main axis, as with CSS `justify-content`. `spaceBetween`
/// pushes them to the edges, while `start` (the schema default), `end`, and `center` pack them
/// together.
public enum LayoutJustify: String, Codable, Sendable, Equatable, CaseIterable {
    case start
    case center
    case end
    case spaceBetween
    case spaceAround
    case spaceEvenly
    case stretch
}

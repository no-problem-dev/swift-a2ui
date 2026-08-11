import A2UICore

/// Style hint a renderer turns into a concrete `Button` appearance.
///
/// `primary` marks the main call to action, `borderless` removes the border and background so the
/// child reads as a link, and `default` leaves the choice to the renderer.
public enum ButtonVariant: String, Codable, Sendable, Equatable, CaseIterable {
    case `default`
    case primary
    case borderless
}

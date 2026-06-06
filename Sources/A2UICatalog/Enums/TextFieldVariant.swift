import A2UICore

public enum TextFieldVariant: String, Codable, Sendable, Equatable, CaseIterable {
    // Case order matches the official catalog's `TextField.variant` enum order (pinned by tests).
    case longText
    case number
    case shortText
    case obscured
}

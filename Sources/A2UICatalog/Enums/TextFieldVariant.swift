import A2UICore

/// テキスト入力フィールドの入力種別。
public enum TextFieldVariant: String, Codable, Sendable, Equatable, CaseIterable {
    // Case order matches the official catalog's `TextField.variant` enum order (pinned by tests).
    case longText
    case number
    case shortText
    case obscured
}

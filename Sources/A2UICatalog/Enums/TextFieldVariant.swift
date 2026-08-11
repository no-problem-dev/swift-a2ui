import A2UICore

/// The kind of field a `TextField` presents, and the only control over keyboard and masking.
///
/// One line (`shortText`, the schema default), a multi-line box (`longText`), numeric entry
/// (`number`), or masked entry (`obscured`).
public enum TextFieldVariant: String, Codable, Sendable, Equatable, CaseIterable {
    // Case order matches the official catalog's `TextField.variant` enum order (pinned by tests).
    case longText
    case number
    case shortText
    case obscured
}

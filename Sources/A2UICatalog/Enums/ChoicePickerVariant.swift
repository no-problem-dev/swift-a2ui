import A2UICore

/// Whether a `ChoicePicker` accepts one selection or several. Its `value` is a list of strings
/// either way; `mutuallyExclusive` simply keeps that list at a single entry.
public enum ChoicePickerVariant: String, Codable, Sendable, Equatable, CaseIterable {
    // Case order matches the official catalog's `ChoicePicker.variant` enum order (pinned by tests).
    case multipleSelection
    case mutuallyExclusive
}

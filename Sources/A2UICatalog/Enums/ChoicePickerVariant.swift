import A2UICore

public enum ChoicePickerVariant: String, Codable, Sendable, Equatable, CaseIterable {
    // Case order matches the official catalog's `ChoicePicker.variant` enum order (pinned by tests).
    case multipleSelection
    case mutuallyExclusive
}

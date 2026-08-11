import A2UICore

/// How a `ChoicePicker` draws its options — a column of checkboxes, or a run of chips. Independent
/// of `ChoicePickerVariant`, which decides how many options may be selected.
public enum ChoicePickerDisplayStyle: String, Codable, Sendable, Equatable, CaseIterable {
    case checkbox
    case chips
}

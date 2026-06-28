import A2UICore

/// 選択肢コンポーネントの選択モード（単一選択または複数選択）。
public enum ChoicePickerVariant: String, Codable, Sendable, Equatable, CaseIterable {
    // Case order matches the official catalog's `ChoicePicker.variant` enum order (pinned by tests).
    case multipleSelection
    case mutuallyExclusive
}

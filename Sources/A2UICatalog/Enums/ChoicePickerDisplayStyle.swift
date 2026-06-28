import A2UICore

/// 選択肢コンポーネントの表示形式。
public enum ChoicePickerDisplayStyle: String, Codable, Sendable, Equatable, CaseIterable {
    case checkbox
    case chips
}

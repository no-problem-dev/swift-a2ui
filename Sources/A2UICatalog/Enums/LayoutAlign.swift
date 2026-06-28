import A2UICore

/// 子コンポーネントの交差軸方向の揃え方。CSS の `align-items` に相当する。
public enum LayoutAlign: String, Codable, Sendable, Equatable, CaseIterable {
    case start
    case center
    case end
    case stretch
}

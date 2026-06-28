import A2UICore

/// 子コンポーネントの主軸方向の配置方法。CSS の `justify-content` に相当する。
public enum LayoutJustify: String, Codable, Sendable, Equatable, CaseIterable {
    case start
    case center
    case end
    case spaceBetween
    case spaceAround
    case spaceEvenly
    case stretch
}

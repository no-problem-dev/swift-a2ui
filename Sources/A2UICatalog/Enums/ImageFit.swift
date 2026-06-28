import A2UICore

/// 画像をコンテナに合わせるリサイズ方法。CSS の `object-fit` プロパティに相当する。
public enum ImageFit: String, Codable, Sendable, Equatable, CaseIterable {
    case contain
    case cover
    case fill
    case none
    case scaleDown
}

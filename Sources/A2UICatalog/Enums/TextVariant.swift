import A2UICore

/// テキストの基本スタイルヒント。レンダラーが見出しサイズやキャプションなどのスタイルに適用する。
public enum TextVariant: String, Codable, Sendable, Equatable, CaseIterable {
    case h1
    case h2
    case h3
    case h4
    case h5
    case caption
    case body
}

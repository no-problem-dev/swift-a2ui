import A2UICore

/// テキストの基本スタイルヒント。
///
/// v1.0 で見出し（`h1`〜`h5`）は廃止され、`caption` / `body` の 2 つになった。
/// 公式テストケース `text_variants.json` は `"h1"` を **invalid** として固定している。
/// 見出しの表現は Markdown（`Text.text` は簡易 Markdown を解釈する）で行う。
public enum TextVariant: String, Codable, Sendable, Equatable, CaseIterable {
    case caption
    case body
}

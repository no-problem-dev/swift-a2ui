import A2UICore

/// Base style hint for a `Text`.
///
/// v1.0 dropped the heading variants (`h1` through `h5`), leaving only `caption` and `body`; the
/// official test case `text_variants.json` pins `"h1"` as invalid. Headings are written as
/// Markdown instead, which `Text.text` interprets.
public enum TextVariant: String, Codable, Sendable, Equatable, CaseIterable {
    case caption
    case body
}

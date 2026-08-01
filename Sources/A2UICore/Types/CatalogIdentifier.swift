import Foundation

/// カタログの識別子（コンポーネント名・関数名・引数/プロパティ名）の命名規則（A2UI v1.0）。
///
/// 仕様は Unicode Standard Annex #31 の変数名規則への準拠を **MUST** とし、正規表現を示している:
///
/// ```regex
/// ^[\p{XID_Start}_][\p{XID_Continue}]*$
/// ```
///
/// SDK・パーサー・コードジェネレータをまたいだ互換性のための制約であり、空白・`Pattern_Syntax`
/// の記号（`-` `#` `$` など）・先頭の数字を弾く。
public enum CatalogIdentifier {

    /// 仕様が定めるカノニカル正規表現。
    public static let pattern = #"^[\p{XID_Start}_][\p{XID_Continue}]*$"#

    private static let regex = try! NSRegularExpression(pattern: pattern)

    /// UAX #31 に適合する識別子かどうか。
    ///
    /// - 先頭: `XID_Start` またはアンダースコア（数字は不可）
    /// - 以降: `XID_Continue`（空白・記号は不可）
    public static func isValid(_ identifier: String) -> Bool {
        guard !identifier.isEmpty else { return false }
        let range = NSRange(identifier.startIndex..<identifier.endIndex, in: identifier)
        return regex.firstMatch(in: identifier, range: range) != nil
    }

    /// 不適合な識別子を返す（適合していれば空）。カタログ検証のまとめ用。
    public static func invalidIdentifiers(in identifiers: some Sequence<String>) -> [String] {
        identifiers.filter { !isValid($0) }
    }
}

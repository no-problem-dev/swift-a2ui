import Foundation

/// The naming rule every catalog identifier must satisfy: component names, function names, and
/// argument or property names (A2UI v1.0).
///
/// The specification makes conformance to the variable-name rules of Unicode Standard Annex #31 a
/// MUST, and gives the regular expression:
///
/// ```regex
/// ^[\p{XID_Start}_][\p{XID_Continue}]*$
/// ```
///
/// The constraint exists so an identifier survives every SDK, parser, and code generator: it
/// rejects whitespace, `Pattern_Syntax` punctuation (`-`, `#`, `$`, …), and a leading digit.
/// Letters outside ASCII are fine.
public enum CatalogIdentifier {

    /// The canonical expression from the specification, verbatim — `isValid(_:)` is compiled from
    /// this, so quoting it elsewhere is how the two drift apart.
    public static let pattern = #"^[\p{XID_Start}_][\p{XID_Continue}]*$"#

    private static let regex = try! NSRegularExpression(pattern: pattern)

    /// Returns whether `identifier` conforms to UAX #31, rejecting the empty string.
    ///
    /// - First character: `XID_Start` or an underscore — never a digit.
    /// - The rest: `XID_Continue` — no whitespace, no punctuation.
    public static func isValid(_ identifier: String) -> Bool {
        guard !identifier.isEmpty else { return false }
        let range = NSRange(identifier.startIndex..<identifier.endIndex, in: identifier)
        return regex.firstMatch(in: identifier, range: range) != nil
    }

    /// Returns the identifiers that do not conform, empty when they all do.
    ///
    /// Use it to report everything wrong with a catalog in one pass instead of stopping at the
    /// first bad name.
    public static func invalidIdentifiers(in identifiers: some Sequence<String>) -> [String] {
        identifiers.filter { !isValid($0) }
    }
}

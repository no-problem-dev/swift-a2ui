/// A JSON Pointer (RFC 6901) reference into the surface's data model, and the only part of a
/// dynamic value that a later `UpdateDataModel` can change.
///
/// A `path` starting with `/` resolves from the root; anything else resolves against the current
/// scope, which is how a component inside a template instance addresses its own element. A path
/// that matches nothing is not an error — the reader coerces it to `""`, `false`, or `0`, so a
/// typo shows up as an empty label rather than a failure.
public struct DataBinding: Codable, Sendable, Equatable, Hashable {
    public let path: String

    public init(path: String) {
        self.path = path
    }
}

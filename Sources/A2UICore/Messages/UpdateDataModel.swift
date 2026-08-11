import StructuredDataCore
/// Writes `value` into a surface's data model at the JSON Pointer `path`, which re-resolves every
/// binding that reads through it (A2UI v1.0).
///
/// `value` is required: to remove a key send an explicit `.null`, because omitting the field fails
/// schema validation. An omitted `path`, or `"/"`, addresses the whole data model.
public struct UpdateDataModel: Codable, Sendable, Equatable {
    public let surfaceId: String
    public let path: String?
    /// The value to write. `.null` deletes the key at `path` rather than storing a null there.
    public let value: StructuredValue

    public init(
        surfaceId: String,
        path: String? = nil,
        value: StructuredValue
    ) {
        self.surfaceId = surfaceId
        self.path = path
        self.value = value
    }
}

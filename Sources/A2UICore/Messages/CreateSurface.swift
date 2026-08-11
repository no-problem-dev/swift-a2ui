import StructuredDataCore
/// Opens a surface on the client — the first message an agent sends for any UI (A2UI v1.0).
///
/// `components` and `dataModel` are optional and behave exactly like an `updateComponents` /
/// `updateDataModel` sent immediately afterwards. The data model is applied first, so bindings
/// already resolve by the time the root component appears and the first paint never flashes empty.
///
/// `surfaceId` must be globally unique for the lifetime of the renderer. Re-creating a live id
/// without deleting it first is a spec violation.
public struct CreateSurface: Codable, Sendable, Equatable {
    public let surfaceId: String
    /// Default catalog for the surface, used by every component and function call that does not
    /// name a `catalogId` of its own (see `A2UIComponentProtocol.catalogId`). Optional.
    public let catalogId: String?
    public let sendDataModel: Bool?
    /// Components for the first paint, in the same shape as `UpdateComponents.components`, so the
    /// surface and its contents arrive in one message.
    public let components: [StructuredValue]?
    /// Root object of the data model, applied before `components` so their bindings resolve.
    public let dataModel: StructuredValue?

    public init(
        surfaceId: String,
        catalogId: String? = nil,
        sendDataModel: Bool? = nil,
        components: [StructuredValue]? = nil,
        dataModel: StructuredValue? = nil
    ) {
        self.surfaceId = surfaceId
        self.catalogId = catalogId
        self.sendDataModel = sendDataModel
        self.components = components
        self.dataModel = dataModel
    }
}

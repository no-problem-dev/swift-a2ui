public struct CreateSurface: Codable, Sendable, Equatable {
    public let surfaceId: String
    public let catalogId: String
    public let theme: StructuredValue?
    public let sendDataModel: Bool?
    /// v0.10: optional initial component list (atomic first paint). Mirrors `updateComponents.components`.
    public let components: [StructuredValue]?
    /// v0.10: optional initial root data model object.
    public let dataModel: StructuredValue?

    public init(
        surfaceId: String,
        catalogId: String,
        theme: StructuredValue? = nil,
        sendDataModel: Bool? = nil,
        components: [StructuredValue]? = nil,
        dataModel: StructuredValue? = nil
    ) {
        self.surfaceId = surfaceId
        self.catalogId = catalogId
        self.theme = theme
        self.sendDataModel = sendDataModel
        self.components = components
        self.dataModel = dataModel
    }
}

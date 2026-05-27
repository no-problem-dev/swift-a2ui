public struct CreateSurface: Codable, Sendable, Equatable {
    public let surfaceId: String
    public let catalogId: String
    public let theme: AnyCodable?
    public let sendDataModel: Bool?

    public init(
        surfaceId: String,
        catalogId: String,
        theme: AnyCodable? = nil,
        sendDataModel: Bool? = nil
    ) {
        self.surfaceId = surfaceId
        self.catalogId = catalogId
        self.theme = theme
        self.sendDataModel = sendDataModel
    }
}

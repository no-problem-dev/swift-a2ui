import A2UICore

/// Immutable snapshot of a single surface's state.
public struct SurfaceState: Sendable, Equatable {
    public let id: String
    public let catalogId: String
    public let theme: AnyCodable?
    public let sendDataModel: Bool
    public var components: [String: AnyCodable]
    public var dataModel: AnyCodable

    public init(
        id: String,
        catalogId: String,
        theme: AnyCodable? = nil,
        sendDataModel: Bool = false,
        components: [String: AnyCodable] = [:],
        dataModel: AnyCodable = .object([:])
    ) {
        self.id = id
        self.catalogId = catalogId
        self.theme = theme
        self.sendDataModel = sendDataModel
        self.components = components
        self.dataModel = dataModel
    }
}

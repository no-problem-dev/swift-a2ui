import A2UICore
import Foundation
import Observation

/// The reactive state of a single UI surface (spec §3 `SurfaceModel`).
///
/// Holds the `DataModel` and the `SurfaceComponentsModel`. `@Observable` so SwiftUI can observe
/// surface-level changes; exposes `onAction` for user-action dispatch back to the host/transport.
@Observable
public final class SurfaceModel: Identifiable {
    public let id: String
    public let catalogId: String
    public let theme: StructuredValue?
    /// If true, the host should send this surface's full data model with client→server messages.
    public let sendDataModel: Bool

    @ObservationIgnored
    public let dataModel: DataModel
    public let components: SurfaceComponentsModel

    @ObservationIgnored
    public let onAction = EventSource<UserAction>()

    public init(
        id: String,
        catalogId: String,
        theme: StructuredValue? = nil,
        sendDataModel: Bool = false,
        dataModel: DataModel = DataModel(),
        components: SurfaceComponentsModel = SurfaceComponentsModel()
    ) {
        self.id = id
        self.catalogId = catalogId
        self.theme = theme
        self.sendDataModel = sendDataModel
        self.dataModel = dataModel
        self.components = components
    }

    /// Dispatch a user action originating from a component in this surface.
    /// Timestamps with the current time in ISO 8601 (spec `action` schema).
    public func dispatchAction(name: String, sourceComponentId: String, context: [String: StructuredValue]) {
        let action = UserAction(
            name: name,
            surfaceId: id,
            sourceComponentId: sourceComponentId,
            timestamp: ISO8601DateFormatter().string(from: Date()),
            context: context
        )
        onAction.emit(action)
    }
}

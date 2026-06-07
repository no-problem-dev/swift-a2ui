import A2ACore
import A2UICore

/// What the client can render: catalog IDs it supports and optional inline catalogs.
/// Travels on `Message.metadata` so catalog negotiation never enters an LLM prompt.
public struct A2UIClientCapabilities: Codable, Sendable, Equatable {
    public var supportedCatalogIds: [String]
    /// Full catalog definitions for agents that accept inline catalogs (raw catalog JSON).
    public var inlineCatalogs: [StructuredValue]?

    public init(supportedCatalogIds: [String] = [], inlineCatalogs: [StructuredValue]? = nil) {
        self.supportedCatalogIds = supportedCatalogIds
        self.inlineCatalogs = inlineCatalogs
    }
}

/// The client-side data model snapshot, per surface. An orchestrator forwards only the
/// surfaces owned by the target agent (the official sample's "Data Model Stripping").
public struct A2UIClientDataModel: Codable, Sendable, Equatable {
    public var surfaces: [String: StructuredValue]

    public init(surfaces: [String: StructuredValue] = [:]) {
        self.surfaces = surfaces
    }

    /// A copy keeping only the given surfaces — the stripping primitive. Ownership
    /// (which agent may see which surface) is the caller's knowledge.
    public func keeping(_ surfaceIds: some Sequence<String>) -> A2UIClientDataModel {
        let kept = Set(surfaceIds)
        return A2UIClientDataModel(surfaces: surfaces.filter { kept.contains($0.key) })
    }
}

/// `Message.metadata` keys and typed accessors for the A2UI vocabulary
/// (mirror of the official orchestrator's metadata handling).
public enum A2UIMessageMetadata {
    /// Official `A2UI_CLIENT_CAPABILITIES_KEY`.
    public static let clientCapabilitiesKey = "a2uiClientCapabilities"
    /// Official `a2uiClientDataModel` key.
    public static let clientDataModelKey = "a2uiClientDataModel"

    public static func clientCapabilities(in metadata: A2AMetadata?) -> A2UIClientCapabilities? {
        metadata?[clientCapabilitiesKey].flatMap { try? $0.decode(A2UIClientCapabilities.self) }
    }

    public static func clientDataModel(in metadata: A2AMetadata?) -> A2UIClientDataModel? {
        metadata?[clientDataModelKey].flatMap { try? $0.decode(A2UIClientDataModel.self) }
    }

    public static func embed(_ capabilities: A2UIClientCapabilities, into metadata: inout A2AMetadata) throws {
        metadata[clientCapabilitiesKey] = try .encoding(capabilities)
    }

    public static func embed(_ dataModel: A2UIClientDataModel, into metadata: inout A2AMetadata) throws {
        metadata[clientDataModelKey] = try .encoding(dataModel)
    }
}

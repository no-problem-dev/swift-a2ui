import StructuredDataCore
import A2ACore
import A2UICore

/// What the client can render: the catalog IDs it supports, plus optional inline catalogs.
///
/// Travels in `Message.metadata` so that catalog negotiation never has to enter the LLM prompt.
public struct A2UIRendererCapabilities: Codable, Sendable, Equatable {
    public var supportedCatalogIds: [String]
    /// Raw catalog JSON, worth sending only to agents whose card declares `acceptsInlineCatalogs`.
    public var inlineCatalogs: [StructuredValue]?

    public init(supportedCatalogIds: [String] = [], inlineCatalogs: [StructuredValue]? = nil) {
        self.supportedCatalogIds = supportedCatalogIds
        self.inlineCatalogs = inlineCatalogs
    }
}

/// A snapshot of the client-side data model, keyed by surface.
///
/// An orchestrator forwards only the surfaces the target agent owns — "Data Model Stripping" in
/// the official samples.
public struct A2UIRendererDataModel: Codable, Sendable, Equatable {
    /// Protocol version. In v1.0 `renderer_data_model.json` keeps it flat, as a sibling of
    /// `surfaces`, rather than wrapping the payload in a version key the way capabilities do.
    public var version: String
    public var surfaces: [String: StructuredValue]

    public init(surfaces: [String: StructuredValue] = [:], version: String = A2UIVersion.current) {
        self.version = version
        self.surfaces = surfaces
    }

    /// Returns a copy holding only the named surfaces — the primitive that stripping is built on.
    ///
    /// Which agent may see which surface is the caller's knowledge, not this type's. Unknown IDs
    /// are ignored, so the result can be empty.
    ///
    /// The copy keeps the version it was given. Selecting surfaces says nothing about which
    /// protocol the sender was speaking, and restamping a foreign version as the current one
    /// erases the only evidence of a real incompatibility: the receiver then reads a v0.9 payload
    /// as v1.0, and the mismatch resurfaces later as an unexplained decode failure.
    public func keeping(_ surfaceIds: some Sequence<String>) -> A2UIRendererDataModel {
        let kept = Set(surfaceIds)
        return A2UIRendererDataModel(
            surfaces: surfaces.filter { kept.contains($0.key) },
            version: version
        )
    }
}

/// The `Message.metadata` keys of the A2UI vocabulary, with typed accessors — mirrors how the
/// official orchestrator reads and writes that metadata.
public enum A2UIMessageMetadata {
    /// Metadata key for renderer capabilities; the official `A2UI_CLIENT_CAPABILITIES_KEY`.
    public static let rendererCapabilitiesKey = "a2uiRendererCapabilities"
    /// Metadata key for the renderer data model; the official `a2uiRendererDataModel` key.
    public static let rendererDataModelKey = "a2uiRendererDataModel"

    /// Reads renderer capabilities out of message metadata.
    ///
    /// In v1.0 capabilities nest under a version key
    /// (`{"a2uiRendererCapabilities": {"v1.0": {"supportedCatalogIds": […]}}}`). A payload that is
    /// not nested is decoded as it stands, so senders on either shape are understood.
    /// `nil` covers both "no capabilities key" and "the key held something undecodable".
    public static func rendererCapabilities(in metadata: A2AMetadata?) -> A2UIRendererCapabilities? {
        guard let envelope = metadata?[rendererCapabilitiesKey] else { return nil }
        // Read the block for the current version; failing that, read the envelope as an
        // un-nested payload.
        if let versioned = try? envelope[A2UIVersion.current].decode(A2UIRendererCapabilities.self),
           !versioned.supportedCatalogIds.isEmpty || versioned.inlineCatalogs != nil {
            return versioned
        }
        return try? envelope.decode(A2UIRendererCapabilities.self)
    }

    public static func rendererDataModel(in metadata: A2AMetadata?) -> A2UIRendererDataModel? {
        metadata?[rendererDataModelKey].flatMap { try? $0.decode(A2UIRendererDataModel.self) }
    }

    public static func embed(_ capabilities: A2UIRendererCapabilities, into metadata: inout A2AMetadata) throws {
        metadata[rendererCapabilitiesKey] = .object([A2UIVersion.current: try .encoded(capabilities)])
    }

    public static func embed(_ dataModel: A2UIRendererDataModel, into metadata: inout A2AMetadata) throws {
        metadata[rendererDataModelKey] = try .encoded(dataModel)
    }
}

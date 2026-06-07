import A2ACore
import A2UICore

/// The A2UI extension to the A2A protocol (mirror of the Python SDK's `a2ui/a2a/extension.py`).
///
/// Agents that emit A2UI declare it on their `AgentCard.capabilities.extensions`;
/// orchestrators discover catalog support from that declaration instead of any LLM prompt.
public enum A2UIExtension {
    /// Namespace identifier, not a fetchable URL (it 404s by design, like an XML namespace).
    /// Only ever string-matched; defined verbatim in the official extension specification.
    public static let baseURI = "https://a2ui.org/a2a-extension/a2ui"

    /// Versioned extension URI, e.g. `https://a2ui.org/a2a-extension/a2ui/v0.10`.
    /// The official format is `{base}/v{version}`; `A2UIVersion` constants carry the `v` prefix.
    public static let uri = "\(baseURI)/\(A2UIVersion.current)"

    /// Official `AGENT_EXTENSION_SUPPORTED_CATALOG_IDS_KEY`.
    public static let supportedCatalogIdsKey = "supportedCatalogIds"
    /// Official `AGENT_EXTENSION_ACCEPTS_INLINE_CATALOGS_KEY`.
    public static let acceptsInlineCatalogsKey = "acceptsInlineCatalogs"

    /// Builds the card declaration (mirror of `get_a2ui_agent_extension`).
    public static func agentExtension(
        supportedCatalogIds: [String] = [],
        acceptsInlineCatalogs: Bool = false
    ) -> AgentExtension {
        var params: A2AMetadata = [:]
        if acceptsInlineCatalogs {
            params[acceptsInlineCatalogsKey] = .bool(true)
        }
        if !supportedCatalogIds.isEmpty {
            params[supportedCatalogIdsKey] = .array(supportedCatalogIds.map { .string($0) })
        }
        return AgentExtension(
            uri: uri,
            description: "Provides agent driven UI using the A2UI JSON format.",
            params: params.isEmpty ? nil : params
        )
    }

    /// A parsed A2UI declaration from a remote agent's card.
    public struct Declaration: Sendable, Equatable {
        /// Version segment of the URI, e.g. `"v0.10"`.
        public let version: String
        public let supportedCatalogIds: [String]
        public let acceptsInlineCatalogs: Bool

        public init(version: String, supportedCatalogIds: [String], acceptsInlineCatalogs: Bool) {
            self.version = version
            self.supportedCatalogIds = supportedCatalogIds
            self.acceptsInlineCatalogs = acceptsInlineCatalogs
        }
    }

    /// All A2UI declarations on a card, in card order (mirror of the orchestrator's
    /// `A2UI_EXTENSION_BASE_URI` prefix scan over `capabilities.extensions`).
    public static func declarations(in card: AgentCard) -> [Declaration] {
        card.capabilities.extensions.compactMap { ext in
            guard ext.uri.hasPrefix(baseURI + "/") else { return nil }
            let params = ext.params ?? [:]
            return Declaration(
                version: String(ext.uri.dropFirst(baseURI.count + 1)),
                supportedCatalogIds: params[supportedCatalogIdsKey]?.arrayValue?.compactMap(\.stringValue) ?? [],
                acceptsInlineCatalogs: params[acceptsInlineCatalogsKey]?.boolValue ?? false
            )
        }
    }

    /// The declaration matching this library's A2UI version, if the card has one.
    public static func currentDeclaration(in card: AgentCard) -> Declaration? {
        declarations(in: card).first { $0.version == A2UIVersion.current }
    }
}

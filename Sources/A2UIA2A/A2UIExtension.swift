import A2ACore
import A2UICore

/// The A2UI extension to the A2A protocol — mirrors the Python SDK's `a2ui/a2a/extension.py`.
///
/// An agent that emits A2UI declares it in `AgentCard.capabilities.extensions`. An orchestrator
/// reads catalog support out of that declaration, so nothing about it has to reach the LLM prompt.
public enum A2UIExtension {
    /// Namespace identifier, not a fetchable URL — it 404s by design, like an XML namespace.
    /// Use it for string matching only. Defined verbatim by the official extension spec.
    public static let baseURI = "https://a2ui.org/a2a-extension/a2ui"

    /// Versioned extension URI, for example `https://a2ui.org/a2a-extension/a2ui/v1.0`.
    /// The official format is `{base}/v{version}`; the `A2UIVersion` constants already carry
    /// the `v`, so nothing here adds one.
    public static let uri = "\(baseURI)/\(A2UIVersion.current)"

    /// Params key listing the catalogs an agent supports; the official
    /// `AGENT_EXTENSION_SUPPORTED_CATALOG_IDS_KEY`.
    public static let supportedCatalogIdsKey = "supportedCatalogIds"
    /// Params key flagging that an agent takes inline catalogs; the official
    /// `AGENT_EXTENSION_ACCEPTS_INLINE_CATALOGS_KEY`.
    public static let acceptsInlineCatalogsKey = "acceptsInlineCatalogs"

    /// Builds the declaration to put on an `AgentCard` — mirrors `get_a2ui_agent_extension`.
    ///
    /// Only the flags that are actually set appear in `params`, and `params` itself is left `nil`
    /// when neither is.
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

    /// An A2UI declaration parsed off a remote agent's card.
    public struct Declaration: Sendable, Equatable {
        /// Version segment of the declared URI, for example `"v1.0"`. Any version the card names
        /// is parsed, so compare it against `A2UIVersion.current` before assuming compatibility.
        public let version: String
        public let supportedCatalogIds: [String]
        public let acceptsInlineCatalogs: Bool

        public init(version: String, supportedCatalogIds: [String], acceptsInlineCatalogs: Bool) {
            self.version = version
            self.supportedCatalogIds = supportedCatalogIds
            self.acceptsInlineCatalogs = acceptsInlineCatalogs
        }
    }

    /// Returns every A2UI declaration on the card, in card order — mirrors the orchestrator's
    /// `A2UI_EXTENSION_BASE_URI` prefix scan over `capabilities.extensions`.
    ///
    /// A card may declare several versions; missing params decode to an empty ID list and
    /// `false`, which is indistinguishable from an agent that declared them that way.
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

    /// Returns the declaration matching this library's A2UI version, or `nil` when the card
    /// declares only other versions — which is the check to make before sending A2UI to an agent.
    public static func currentDeclaration(in card: AgentCard) -> Declaration? {
        declarations(in: card).first { $0.version == A2UIVersion.current }
    }
}

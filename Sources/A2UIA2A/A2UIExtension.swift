import A2ACore
import A2UICore

/// A2A プロトコルへの A2UI 拡張（Python SDK の `a2ui/a2a/extension.py` のミラー）。
///
/// A2UI を出力するエージェントは `AgentCard.capabilities.extensions` に宣言する。
/// オーケストレータはその宣言からカタログ対応を検出し、LLM プロンプトに依存しない。
public enum A2UIExtension {
    /// 名前空間識別子。フェッチ可能な URL ではない（設計上 404 になる、XML 名前空間と同様）。
    /// 文字列マッチングのみで使用する。公式拡張仕様にそのまま定義されている。
    public static let baseURI = "https://a2ui.org/a2a-extension/a2ui"

    /// バージョン付き拡張 URI（例: `https://a2ui.org/a2a-extension/a2ui/v0.10`）。
    /// 公式フォーマットは `{base}/v{version}`; `A2UIVersion` の定数は `v` プレフィックスを持つ。
    public static let uri = "\(baseURI)/\(A2UIVersion.current)"

    /// 公式 `AGENT_EXTENSION_SUPPORTED_CATALOG_IDS_KEY`。
    public static let supportedCatalogIdsKey = "supportedCatalogIds"
    /// 公式 `AGENT_EXTENSION_ACCEPTS_INLINE_CATALOGS_KEY`。
    public static let acceptsInlineCatalogsKey = "acceptsInlineCatalogs"

    /// カード宣言を構築する（`get_a2ui_agent_extension` のミラー）。
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

    /// リモートエージェントのカードから解析した A2UI 宣言。
    public struct Declaration: Sendable, Equatable {
        /// URI のバージョンセグメント（例: `"v0.10"`）。
        public let version: String
        public let supportedCatalogIds: [String]
        public let acceptsInlineCatalogs: Bool

        public init(version: String, supportedCatalogIds: [String], acceptsInlineCatalogs: Bool) {
            self.version = version
            self.supportedCatalogIds = supportedCatalogIds
            self.acceptsInlineCatalogs = acceptsInlineCatalogs
        }
    }

    /// カード上のすべての A2UI 宣言をカード順で返す（オーケストレータの
    /// `capabilities.extensions` に対する `A2UI_EXTENSION_BASE_URI` プレフィックス探索のミラー）。
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

    /// カードにこのライブラリの A2UI バージョンに一致する宣言があれば返す。
    public static func currentDeclaration(in card: AgentCard) -> Declaration? {
        declarations(in: card).first { $0.version == A2UIVersion.current }
    }
}

import Foundation
import A2UICatalog
import A2UICore

/// Builds LLM system prompts in the official Google A2UI format.
///
/// `A2UIPromptBuilder` assembles the four sections that the Python SDK
/// produces: role description, workflow rules, optional UI description,
/// and the JSON schema block (server-to-client, common types, catalog).
///
/// ### Example
/// ```swift
/// let builder = A2UIPromptBuilder()
/// let prompt = builder.buildSystemPrompt(
///     role: "You are a helpful assistant that renders UI.",
///     uiDescription: "Show a card with a title and a confirm button."
/// )
/// ```
public struct A2UIPromptBuilder: Sendable {

    // MARK: - Private storage (nil = use bundled resources at call time)

    private let _serverToClientSchema: String?
    private let _commonTypesSchema: String?
    private let _catalogSchema: String?

    /// 残す server_to_client メッセージ型名（例: `["CreateSurfaceMessage", "UpdateComponentsMessage"]`）。
    /// `nil` = プルーニング無効、bundled の oneOf を全て残す。
    private let _allowedMessages: Set<String>?

    /// `true` のとき、catalog と server_to_client から到達可能な common_types の `$defs` のみ残す。
    private let _pruneCommonTypes: Bool

    // MARK: - Init

    /// Initialize using the schemas bundled with A2UIPrompt (server_to_client.json,
    /// common_types.json) and the catalog.json bundled with A2UICatalog.
    public init() {
        _serverToClientSchema = nil
        _commonTypesSchema = nil
        _catalogSchema = nil
        _allowedMessages = nil
        _pruneCommonTypes = false
    }

    /// Initialize with custom schema strings, bypassing the bundled resources.
    ///
    /// Useful for testing or when targeting a different A2UI spec version.
    public init(
        serverToClientSchema: String,
        commonTypesSchema: String,
        catalogSchema: String
    ) {
        _serverToClientSchema = serverToClientSchema
        _commonTypesSchema = commonTypesSchema
        _catalogSchema = catalogSchema
        _allowedMessages = nil
        _pruneCommonTypes = false
    }

    /// Initialize with a custom **catalog** schema while keeping the bundled server-to-client and
    /// common-types schemas.
    public init(
        catalogSchema: String,
        allowedMessages: Set<String>? = nil,
        pruneCommonTypes: Bool = false
    ) {
        _serverToClientSchema = nil
        _commonTypesSchema = nil
        _catalogSchema = catalogSchema
        _allowedMessages = allowedMessages
        _pruneCommonTypes = pruneCommonTypes
    }

    /// 全パラメタを任意で渡せる統合 init。`nil` 指定のフィールドは bundled リソースにフォールバックする。
    /// 派生 builder (`A2UIPromptCompact` 等) が部分カスタムを渡す用途を想定。
    ///
    /// - Parameters:
    ///   - serverToClientSchema: server_to_client schema を上書き。`nil` = bundled
    ///   - commonTypesSchema: common_types schema を上書き。`nil` = bundled
    ///   - catalogSchema: catalog schema を上書き。`nil` = bundled basic catalog
    ///   - allowedMessages: server_to_client `oneOf` を絞る。Python `with_pruning(allowed_messages:)` 相当
    ///   - pruneCommonTypes: catalog と s2c から到達可能な common_types の `$defs` のみ残す
    public init(
        serverToClientSchema: String?,
        commonTypesSchema: String?,
        catalogSchema: String?,
        allowedMessages: Set<String>? = nil,
        pruneCommonTypes: Bool = false
    ) {
        _serverToClientSchema = serverToClientSchema
        _commonTypesSchema = commonTypesSchema
        _catalogSchema = catalogSchema
        _allowedMessages = allowedMessages
        _pruneCommonTypes = pruneCommonTypes
    }

    // MARK: - Bundled resources (public)

    /// Bundled `server_to_client.json` を文字列で返す（minify 後）。派生 builder 用のフック。
    public static func bundledServerToClientJSON() -> String {
        loadBundledResource("server_to_client")
    }

    /// Bundled `common_types.json` を文字列で返す（minify 後）。派生 builder 用のフック。
    public static func bundledCommonTypesJSON() -> String {
        loadBundledResource("common_types")
    }

    // MARK: - Public API

    /// Build a complete system prompt in the official A2UI format.
    ///
    /// The prompt sections are joined with `\n\n` to produce clean spacing.
    /// Sections are assembled in this order:
    ///
    /// 1. `role` — required, describes the assistant's persona.
    /// 2. `## Workflow Description:` — workflow rules (default or custom).
    /// 3. `## UI Description:` — optional free-form UI description.
    /// 4. The JSON schema block — included when `includeSchema` is `true`.
    ///
    /// - Parameters:
    ///   - role: A description of the LLM's role / persona.
    ///   - workflowRules: Custom workflow rules. Pass `nil` to use
    ///     `A2UIWorkflowRules.default`.
    ///   - uiDescription: Optional description of the expected UI structure.
    ///   - includeSchema: Whether to append the JSON schema block.
    ///     Defaults to `true`.
    /// - Returns: A fully assembled system prompt string.
    public func buildSystemPrompt(
        role: String,
        workflowRules: String? = nil,
        uiDescription: String? = nil,
        examples: String? = nil,
        includeSchema: Bool = true
    ) -> String {
        var sections: [String] = [role]

        let rules = workflowRules ?? A2UIWorkflowRules.default
        sections.append("## Workflow Description:\n\(rules)")

        if let uiDescription {
            sections.append("## UI Description:\n\(uiDescription)")
        }

        if includeSchema {
            sections.append(schemaBlock())
        }

        if let examples {
            sections.append("### Examples:\n\(examples)")
        }

        return sections.joined(separator: "\n\n")
    }

    /// Build just the schema block portion of the prompt.
    ///
    /// The block is formatted by `SchemaBlockFormatter` and contains the
    /// server-to-client, common types, and catalog schemas. Applies `allowedMessages` and
    /// `pruneCommonTypes` opt-ins when set.
    public func schemaBlock() -> String {
        let catalogString = resolvedCatalogSchema
        var s2cString = resolvedServerToClientSchema
        var commonString = resolvedCommonTypesSchema

        // allowed_messages: server_to_client の oneOf / $defs を絞る
        if let allowed = _allowedMessages,
           let parsed = Self.parseJSON(s2cString) {
            let pruned = SchemaPruner.pruneMessages(serverToClient: parsed, allowedMessages: allowed)
            s2cString = Self.serializeJSON(pruned) ?? s2cString
        }

        // prune_common_types: catalog と (絞られた) s2c から到達可能な $defs だけ残す
        if _pruneCommonTypes,
           let common = Self.parseJSON(commonString) {
            let externals = [catalogString, s2cString].compactMap(Self.parseJSON)
            let pruned = SchemaPruner.pruneCommonTypes(commonTypes: common, reachableFrom: externals)
            commonString = Self.serializeJSON(pruned) ?? commonString
        }

        return SchemaBlockFormatter.format(
            serverToClientSchema: s2cString,
            commonTypesSchema: commonString,
            catalogSchema: catalogString
        )
    }

    // MARK: - Schema resolution

    private var resolvedServerToClientSchema: String {
        _serverToClientSchema ?? Self.loadBundledResource("server_to_client")
    }

    private var resolvedCommonTypesSchema: String {
        _commonTypesSchema ?? Self.loadBundledResource("common_types")
    }

    private var resolvedCatalogSchema: String {
        _catalogSchema ?? BasicComponentCatalog.catalogSchemaJSON()
    }

    // MARK: - JSON helpers

    private static func parseJSON(_ string: String) -> StructuredValue? {
        guard let data = string.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(StructuredValue.self, from: data)
    }

    private static func serializeJSON(_ value: StructuredValue) -> String? {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        guard let data = try? encoder.encode(value),
              let string = String(data: data, encoding: .utf8) else {
            return nil
        }
        return string
    }

    /// Load a JSON file from A2UIPrompt's own resource bundle.
    ///
    /// Tries the explicit `Resources/` subdirectory first (which matches the
    /// `.copy("Resources")` layout) and falls back to a flat lookup, which is
    /// the layout SwiftPM produces when `.process("Resources")` flattens the
    /// directory hierarchy.
    private static func loadBundledResource(_ name: String) -> String {
        let url = Bundle.module.url(forResource: name, withExtension: "json", subdirectory: "Resources")
            ?? Bundle.module.url(forResource: name, withExtension: "json")
        guard let url, let data = try? Data(contentsOf: url) else {
            return "{}"
        }
        if let minified = minifyJSON(data) {
            return minified
        }
        return String(data: data, encoding: .utf8) ?? "{}"
    }

    /// Bundled JSON resources をプロンプト埋め込み用に minify する。
    /// Python 公式 (`json.dumps(..., separators=(",", ":"))`) と同等の出力を狙う。
    /// `.sortedKeys` を採用してプロンプトキャッシュヒット率を安定化させる。
    private static func minifyJSON(_ data: Data) -> String? {
        guard let object = try? JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed]),
              let minified = try? JSONSerialization.data(
                  withJSONObject: object,
                  options: [.sortedKeys, .withoutEscapingSlashes]
              ) else {
            return nil
        }
        return String(data: minified, encoding: .utf8)
    }
}

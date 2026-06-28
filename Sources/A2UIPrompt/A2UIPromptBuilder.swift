import Foundation
import A2UICatalog
import A2UICore
import JSONParsing

/// 公式 Google A2UI 形式で LLM システムプロンプトを組み立てるビルダー。
///
/// Python SDK が生成する 4 セクション（role 説明・ワークフロールール・UI 説明（オプション）・
/// JSON スキーマブロック（サーバ→クライアント・共通型・カタログ））を組み立てる。
///
/// ### 使用例
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

    /// 残す catalog コンポーネント名（例: `["Text", "Button"]`）。
    /// `nil` = プルーニング無効、catalog の components を全て残す。
    /// 公開: `SendA2UIToClientTool` がプロンプトと同じ許可セットで検証する（prompt と enforcement の同期）。
    public let allowedComponents: Set<String>?

    /// 残す server_to_client メッセージ型名（例: `["CreateSurfaceMessage", "UpdateComponentsMessage"]`）。
    /// `nil` = プルーニング無効、bundled の oneOf を全て残す。
    /// 公開: `SendA2UIToClientTool` がプロンプトと同じ許可セットで検証する（prompt と enforcement の同期）。
    public let allowedMessages: Set<String>?

    // MARK: - Init

    /// A2UIPrompt にバンドルされたスキーマ（server_to_client.json, common_types.json）と
    /// A2UICatalog にバンドルされた catalog.json を使用して初期化する。
    public init() {
        _serverToClientSchema = nil
        _commonTypesSchema = nil
        _catalogSchema = nil
        allowedComponents = nil
        allowedMessages = nil
    }

    /// カスタムスキーマ文字列を使用して初期化し、バンドルリソースをバイパスする。
    ///
    /// テストや異なる A2UI スペックバージョンを対象にする場合に有用。
    public init(
        serverToClientSchema: String,
        commonTypesSchema: String,
        catalogSchema: String
    ) {
        _serverToClientSchema = serverToClientSchema
        _commonTypesSchema = commonTypesSchema
        _catalogSchema = catalogSchema
        allowedComponents = nil
        allowedMessages = nil
    }

    /// カスタム **catalog** スキーマを指定しつつ、バンドルの server-to-client・
    /// common-types スキーマはそのまま使用して初期化する。
    public init(
        catalogSchema: String,
        allowedComponents: Set<String>? = nil,
        allowedMessages: Set<String>? = nil
    ) {
        _serverToClientSchema = nil
        _commonTypesSchema = nil
        _catalogSchema = catalogSchema
        self.allowedComponents = allowedComponents
        self.allowedMessages = allowedMessages
    }

    /// 全パラメタを任意で渡せる統合 init。`nil` 指定のフィールドは bundled リソースにフォールバックする。
    /// 派生 builder (`A2UIPromptCompact` 等) が部分カスタムを渡す用途を想定。
    ///
    /// 公式 `with_pruning` と同じく、common_types は allowlist の有無に関わらず常に
    /// catalog / s2c からの到達可能性で絞られる。
    ///
    /// - Parameters:
    ///   - serverToClientSchema: server_to_client schema を上書き。`nil` = bundled
    ///   - commonTypesSchema: common_types schema を上書き。`nil` = bundled
    ///   - catalogSchema: catalog schema を上書き。`nil` = bundled basic catalog
    ///   - allowedComponents: catalog `components` を絞る。Python `with_pruning(allowed_components:)` 相当
    ///   - allowedMessages: server_to_client `oneOf` を絞る。Python `with_pruning(allowed_messages:)` 相当
    public init(
        serverToClientSchema: String?,
        commonTypesSchema: String?,
        catalogSchema: String?,
        allowedComponents: Set<String>? = nil,
        allowedMessages: Set<String>? = nil
    ) {
        _serverToClientSchema = serverToClientSchema
        _commonTypesSchema = commonTypesSchema
        _catalogSchema = catalogSchema
        self.allowedComponents = allowedComponents
        self.allowedMessages = allowedMessages
    }

    // MARK: - Presets

    /// presenter（コンテンツ提示）サブセット構成の builder（公式 `with_pruning` 準拠）。
    ///
    /// カタログを `A2UIExample.presenterComponentNames` の 9 コンポーネント、
    /// server_to_client を `A2UIExample.presenterMessageNames` の 3 メッセージに絞る。
    /// 手本（`A2UIExample.presenterSurface`）と同じサブセットで組まれる対 —
    /// pruning したスキーマと手本が矛盾しないことはテストで固定される。
    public static func presenter() -> A2UIPromptBuilder {
        A2UIPromptBuilder(
            serverToClientSchema: nil,
            commonTypesSchema: nil,
            catalogSchema: nil,
            allowedComponents: A2UIExample.presenterComponentNames,
            allowedMessages: A2UIExample.presenterMessageNames
        )
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

    /// 公式 A2UI 形式でシステムプロンプト全体を組み立てる。
    ///
    /// 各セクションは `\n\n` で連結する。以下の順で組み立てる:
    ///
    /// 1. `role` — 必須。アシスタントのペルソナ説明。
    /// 2. `## Workflow Description:` — ワークフロールール（デフォルトまたはカスタム）。
    /// 3. `## UI Description:` — オプション。UI 構造の自由記述。
    /// 4. JSON スキーマブロック — `includeSchema` が `true` の場合に追記。
    ///
    /// - Parameters:
    ///   - role: LLM のロール / ペルソナ説明。
    ///   - workflowRules: カスタムワークフロールール。`nil` で `A2UIWorkflowRules.default` を使用。
    ///   - uiDescription: 期待する UI 構造のオプション説明。
    ///   - includeSchema: JSON スキーマブロックを追記するか。デフォルトは `true`。
    /// - Returns: 完全に組み立てられたシステムプロンプト文字列。
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

    /// プロンプトのスキーマブロック部分のみを組み立てる。
    ///
    /// `SchemaBlockFormatter` が整形し、公式の `with_pruning` パイプライン
    ///（components → messages → common-types 到達可能性、常時実行）を適用した後の
    /// サーバ → クライアント・共通型・カタログスキーマを含む。
    public func schemaBlock() -> String {
        var catalogString = resolvedCatalogSchema
        var s2cString = resolvedServerToClientSchema
        var commonString = resolvedCommonTypesSchema

        if let catalog = Self.parseJSON(catalogString),
           let s2c = Self.parseJSON(s2cString),
           let common = Self.parseJSON(commonString) {
            let pruned = SchemaPruner.withPruning(
                catalog: catalog,
                serverToClient: s2c,
                commonTypes: common,
                allowedComponents: allowedComponents,
                allowedMessages: allowedMessages
            )
            catalogString = Self.serializeJSON(pruned.catalog) ?? catalogString
            s2cString = Self.serializeJSON(pruned.serverToClient) ?? s2cString
            commonString = Self.serializeJSON(pruned.commonTypes) ?? commonString
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
        try? JSONParser().parse(string)
    }

    private static func serializeJSON(_ value: StructuredValue) -> String? {
        JSONSerializer(options: .init(sortKeys: true)).string(from: value)
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
    /// sortKeys でキー順序を決定的にしプロンプトキャッシュヒット率を安定化させる。
    /// スラッシュは非エスケープ(JSONSerializer の既定挙動)。
    private static func minifyJSON(_ data: Data) -> String? {
        guard let value = try? JSONParser().parse(data) else { return nil }
        return JSONSerializer(options: .init(sortKeys: true)).string(from: value)
    }
}

import A2UICatalog
import A2UICore
import A2UIPrompt
import Foundation

/// **非公式最適化版** プロンプトビルダー。
///
/// 用途: catalog に `functions` を一切持たないアプリ向けに、`common_types.json` から
/// `FunctionCall` 関連の型定義を物理的に剥がしてプロンプトを軽量化する。
///
/// - `A2UIPrompt` の `A2UIPromptBuilder` を内部で利用しつつ、bundled common_types を
///   `CommonTypesCompactor` で加工した版に差し替える
/// - `pruneCommonTypes` を常に true にして到達不能な `$defs` も連動して削る
/// - 公開 API は `A2UIPromptBuilder` と互換
///
/// **注意**: spec 標準には `functions` を含む catalog が前提の記述があり、本 builder は
/// catalog 側で `functions: []` を採用していることを前提とした独自最適化である。
public struct A2UIPromptCompactBuilder: Sendable {

    /// 内部で利用している `A2UIPromptBuilder`。`A2UIPromptConfiguration.promptBuilder` などに
    /// そのまま渡せる脱出ハッチ。
    public let builder: A2UIPromptBuilder
    private var inner: A2UIPromptBuilder { builder }

    /// Bundled の compact common_types を 1 度だけ生成してプロセス内で再利用する。
    private static let compactCommonTypes: String =
        CommonTypesCompactor.compact(A2UIPromptBuilder.bundledCommonTypesJSON())

    /// - Parameters:
    ///   - catalogSchema: カスタム catalog JSON。`nil` で A2UIPrompt の bundled basic catalog を使用
    ///   - allowedComponents: catalog `components` を絞る（例: `["Text", "Button"]`）
    ///   - allowedMessages: server_to_client `oneOf` を絞る（例: `["CreateSurfaceMessage", "UpdateComponentsMessage"]`）
    public init(
        catalogSchema: String? = nil,
        allowedComponents: Set<String>? = nil,
        allowedMessages: Set<String>? = nil
    ) {
        self.builder = A2UIPromptBuilder(
            serverToClientSchema: nil,                      // bundled
            commonTypesSchema: Self.compactCommonTypes,     // compact 版
            catalogSchema: catalogSchema,                   // 渡されたものを優先、nil なら bundled
            allowedComponents: allowedComponents,
            allowedMessages: allowedMessages
            // common_types の到達可能性 pruning は公式 with_pruning 準拠で常時適用される
        )
    }

    /// `A2UIPromptBuilder.buildSystemPrompt` と同形。
    public func buildSystemPrompt(
        role: String,
        workflowRules: String? = nil,
        uiDescription: String? = nil,
        examples: String? = nil,
        includeSchema: Bool = true
    ) -> String {
        inner.buildSystemPrompt(
            role: role,
            workflowRules: workflowRules,
            uiDescription: uiDescription,
            examples: examples,
            includeSchema: includeSchema
        )
    }

    public func schemaBlock() -> String {
        inner.schemaBlock()
    }
}

import A2UICore
import Foundation

/// 既に描画済みのサーフェス（`intent: .update` のときに副エージェントへ渡す）。
public struct A2UIPriorSurface: Sendable, Equatable {
    public let surfaceId: String
    /// 直前の components 配列（JSON 文字列）。
    public let componentsJSON: String
    /// 直前のデータモデル（JSON 文字列）。無ければ `nil`。
    public let dataJSON: String?

    public init(surfaceId: String, componentsJSON: String, dataJSON: String? = nil) {
        self.surfaceId = surfaceId
        self.componentsJSON = componentsJSON
        self.dataJSON = dataJSON
    }
}

/// 副エージェントのシステムプロンプトを組み立てる。
///
/// ミラー元: `@ag-ui/a2ui-toolkit` の `buildSubagentPrompt`。セクション順序が仕様:
/// 1. 生成ガイドライン（ヘッダなし・素で先頭）
/// 2. `## Design Guidelines`
/// 3. `## Available Components`（カタログスキーマ）
/// 4. コンポジションガイド（ホスト固有のカタログ知識）
/// 5. `## Editing an existing surface`（更新時のみ）
///
/// カタログ定義はツール引数の JSON Schema には入れず**ここに文字列として埋め込む**
/// （公式と同じ判断）。カタログは実行時に決まり、巨大な union はプロバイダのスキーマ
/// 制約に触れやすく、構造検証は `A2UIValidation` が担うため。
public struct A2UISubagentPrompt: Sendable {
    /// 更新対象のサーフェス情報（`nil` なら新規作成）。
    public struct EditContext: Sendable, Equatable {
        public let prior: A2UIPriorSurface
        /// 自然言語で書かれた変更要求。
        public let changes: String?

        public init(prior: A2UIPriorSurface, changes: String?) {
            self.prior = prior
            self.changes = changes
        }
    }

    private let guidelines: A2UIGuidelines
    private let catalogSchema: String?
    private let renderToolName: String

    public init(
        guidelines: A2UIGuidelines = .default,
        catalogSchema: String? = nil,
        renderToolName: String = A2UISubagentConstants.renderToolName
    ) {
        self.guidelines = guidelines
        self.catalogSchema = catalogSchema
        self.renderToolName = renderToolName
    }

    /// システムプロンプトを組み立てる。
    public func render(editContext: EditContext? = nil) -> String {
        var parts: [String] = []

        if let generation = guidelines.generation.resolve(
            default: A2UIDefaultGuidelines.generation(renderToolName: renderToolName)
        ) {
            parts.append(generation)
        }
        if let design = guidelines.design.resolve(default: A2UIDefaultGuidelines.design) {
            parts.append("## Design Guidelines\n\(design)")
        }
        if let catalogSchema, !catalogSchema.isEmpty {
            parts.append("## Available Components\n\(catalogSchema)")
        }
        if let composition = guidelines.composition, !composition.isEmpty {
            parts.append(composition)
        }
        if let editContext {
            parts.append(Self.editBlock(for: editContext))
        }

        return parts.joined(separator: "\n\n")
    }

    private static func editBlock(for context: EditContext) -> String {
        var block = """
        ## Editing an existing surface
        You are editing surface '\(context.prior.surfaceId)'. Produce the FULL updated \
        components array and data model — not just a diff. Preserve component ids that the \
        user has not asked to change so the renderer can reconcile them.

        ### Previous components
        \(context.prior.componentsJSON)
        """
        if let dataJSON = context.prior.dataJSON, !dataJSON.isEmpty {
            block += "\n\n### Previous data\n\(dataJSON)"
        }
        if let changes = context.changes, !changes.isEmpty {
            block += "\n\n### Requested changes\n\(changes)"
        }
        return block
    }
}

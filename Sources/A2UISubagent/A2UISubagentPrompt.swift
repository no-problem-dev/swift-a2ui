import A2UICore
import Foundation

/// 副エージェントのシステムプロンプトを組み立てる。
///
/// ミラー元: `@ag-ui/a2ui-toolkit` の `buildSubagentPrompt`。セクション順序が仕様:
/// 1. 生成ガイドライン（ヘッダなし・素で先頭）
/// 2. `## Design Guidelines`
/// 3. `## Available Components`（カタログスキーマ）
/// 4. コンポジションガイド（ホスト固有のカタログ知識）
///
/// カタログ定義はツール引数の JSON Schema には入れず**ここに文字列として埋め込む**
/// （公式と同じ判断）。カタログは実行時に決まり、巨大な union はプロバイダのスキーマ
/// 制約に触れやすく、構造検証は `A2UIValidation` が担うため。
public struct A2UISubagentPrompt: Sendable {
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
    public func render() -> String {
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

        return parts.joined(separator: "\n\n")
    }

}

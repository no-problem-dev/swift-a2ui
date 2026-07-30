import A2UICore
import Foundation
import LLMClient
import LLMTool
import StructuredDataCore

/// 外側ツール — メインのプランナーが呼ぶ `generate_a2ui`。
///
/// ミラー元: `@ag-ui/a2ui-toolkit` の `generate_a2ui`。
///
/// 引数は `intent` / `target_surface_id` / `changes` の 3 つだけで、**A2UI JSON を含まない**。
/// メインは「UI を作れ」という意図しか表明できず、実際の JSON 生成は副エージェント
/// (`RenderA2UITool` を強制呼び出しする LLM リクエスト) が担う。これによりメインの
/// システムプロンプトから A2UI スキーマを外せ、テキストへの JSON 流出も原理的に消える。
///
/// `catalogId` はホストの所有物で、モデルは選べない（副エージェントの引数にも無い）。
public struct GenerateA2UITool: TurnEndingTool {
    /// 副エージェントの呼び出し方をホストから注入する。
    ///
    /// - Parameters:
    ///   - prompt: 組み立て済みのシステムプロンプト。
    ///   - attempt: 1 始まりの試行回数（ログ・観測用）。
    /// - Returns: `render_a2ui` の引数。ツール呼び出しが得られなければ `nil`。
    public typealias Invoke = @Sendable (_ prompt: String, _ attempt: Int) async throws -> RenderA2UIArguments?

    /// 生成されたメッセージ列を検証する（ホストのカタログ・allowlist を適用する）。
    public typealias Validate = @Sendable ([ServerMessage]) -> [String]

    public let toolName: String
    private let catalogId: String
    private let prompt: A2UISubagentPrompt
    private let runner: A2UISubagentRunner
    private let invoke: Invoke
    private let validate: Validate

    public init(
        toolName: String = A2UISubagentConstants.generateToolName,
        catalogId: String,
        prompt: A2UISubagentPrompt,
        runner: A2UISubagentRunner = A2UISubagentRunner(),
        invoke: @escaping Invoke,
        validate: @escaping Validate
    ) {
        self.toolName = toolName
        self.catalogId = catalogId
        self.prompt = prompt
        self.runner = runner
        self.invoke = invoke
        self.validate = validate
    }

    public var toolDescription: String { A2UISubagentConstants.generateToolDescription }

    public var inputSchema: JSONSchema {
        .object(
            properties: [
                "intent": .string(description: A2UISubagentConstants.GenerateArgDescriptions.intent),
                "target_surface_id": .string(
                    description: A2UISubagentConstants.GenerateArgDescriptions.targetSurfaceId
                ),
                "changes": .string(description: A2UISubagentConstants.GenerateArgDescriptions.changes),
            ],
            required: []
        )
    }

    public func execute(with argumentsData: Data) async throws -> ToolResult {
        let args = GenerateArgs(argumentsData: argumentsData)

        // 更新意図でも直前サーフェスの復元はホストの責務（履歴の持ち方に依存する）。
        // ここでは意図と変更要求だけをプロンプトに反映する。
        let editContext = args.targetSurfaceId.map { surfaceId in
            A2UISubagentPrompt.EditContext(
                prior: A2UIPriorSurface(surfaceId: surfaceId, componentsJSON: "[]"),
                changes: args.changes
            )
        }
        let basePrompt = prompt.render(editContext: editContext)

        let result = try await runner.run(
            basePrompt: basePrompt,
            invoke: invoke,
            buildMessages: { rendered in
                Self.messages(
                    from: rendered,
                    catalogId: catalogId,
                    // 更新時は対象サーフェスを維持する（モデルが別 ID を返しても上書きしない）
                    surfaceIdOverride: args.targetSurfaceId
                )
            },
            validate: validate
        )

        guard result.ok else {
            let detail = result.attempts.last?.issues.joined(separator: "; ") ?? "unknown"
            return .error(
                "Failed to generate valid A2UI after \(result.attempts.count) attempt(s)"
                    + " [\(A2UISubagentConstants.recoveryExhaustedCode)]: \(detail)"
            )
        }

        // 公式のエンベロープ形（`wrapAsOperationsEnvelope`）と同じキーで返す。
        // 生の operations がそのままツール結果として履歴に残り、メインが必要なら読める
        // （更新時は履歴から前回のサーフェスを復元する設計）。
        return .json(try JSONEncoder().encode(OperationsEnvelope(a2ui_operations: result.messages)))
    }

    /// `render_a2ui` の引数を A2UI メッセージ列へ変換する。
    ///
    /// `catalogId` はホスト固定。`surfaceId` はモデル出力が untrusted なので空文字を弾き、
    /// 更新時は `surfaceIdOverride`（プランナーが指定した対象）を優先する。
    static func messages(
        from args: RenderA2UIArguments,
        catalogId: String,
        surfaceIdOverride: String? = nil
    ) -> [ServerMessage] {
        let resolved = surfaceIdOverride ?? args.surfaceId
        let surfaceId = resolved.isEmpty ? A2UISubagentConstants.defaultSurfaceId : resolved
        var messages: [ServerMessage] = [
            .createSurface(CreateSurface(surfaceId: surfaceId, catalogId: catalogId)),
        ]
        // createSurface 単独は送らない（空サーフェスはレンダラが root を解決できない）。
        if !args.components.isEmpty {
            messages.append(.updateComponents(UpdateComponents(surfaceId: surfaceId, components: args.components)))
        }
        if let data = args.data {
            messages.append(.updateDataModel(UpdateDataModel(surfaceId: surfaceId, path: "/", value: data)))
        }
        return messages
    }

}

/// 外側ツールの引数。全て optional（`intent` 未指定は `create` 扱い）。
struct GenerateArgs {
    let isUpdate: Bool
    let targetSurfaceId: String?
    let changes: String?

    init(argumentsData: Data) {
        let root = try? JSONParser().parse(argumentsData)
        let intent = root?["intent"].stringValue?.lowercased()
        let target = root?["target_surface_id"].stringValue
        isUpdate = intent == "update"
        targetSurfaceId = isUpdate ? (target?.isEmpty == false ? target : nil) : nil
        let changes = root?["changes"].stringValue
        self.changes = changes?.isEmpty == false ? changes : nil
    }
}

/// 公式 `wrapAsOperationsEnvelope` と同じエンベロープ形。
private struct OperationsEnvelope: Encodable {
    let a2ui_operations: [ServerMessage]
}

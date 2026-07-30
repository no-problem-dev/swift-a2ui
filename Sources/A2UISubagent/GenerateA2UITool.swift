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
            buildMessages: { rendered in Self.messages(from: rendered, catalogId: catalogId) },
            validate: validate
        )

        guard result.ok else {
            let detail = result.attempts.last?.issues.joined(separator: "; ") ?? "unknown"
            return .error(
                "Failed to generate valid A2UI after \(result.attempts.count) attempt(s)"
                    + " [\(A2UISubagentConstants.recoveryExhaustedCode)]: \(detail)"
            )
        }

        return .json(try JSONEncoder().encode(GeneratedPayload(
            validated_a2ui_json: result.messages,
            summary: Self.summary(of: result.messages)
        )))
    }

    /// `render_a2ui` の引数を A2UI メッセージ列へ変換する。
    ///
    /// `catalogId` はホスト固定。`surfaceId` はモデル出力が untrusted なので空文字を弾く。
    static func messages(from args: RenderA2UIArguments, catalogId: String) -> [ServerMessage] {
        let surfaceId = args.surfaceId.isEmpty ? A2UISubagentConstants.defaultSurfaceId : args.surfaceId
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

    /// メインエージェント向けの人間可読な要約。
    ///
    /// 公式にはない delish 側の補強 — 2 段構成ではメインが「何を描画したか」を
    /// 直接知らないため、後続ターンで参照できる短い説明を添える。
    static func summary(of messages: [ServerMessage]) -> String {
        var surfaceIds: [String] = []
        var componentCount = 0
        var texts: [String] = []
        for message in messages {
            switch message {
            case .createSurface(let cs):
                surfaceIds.append(cs.surfaceId)
            case .updateComponents(let uc):
                componentCount += uc.components.count
                for component in uc.components {
                    if let text = component.rawValue["text"].stringValue, !text.isEmpty {
                        texts.append(text)
                    }
                }
            default:
                break
            }
        }
        var parts: [String] = []
        if !surfaceIds.isEmpty {
            parts.append("Rendered surface(s): \(surfaceIds.joined(separator: ", "))")
        }
        parts.append("\(componentCount) component(s)")
        if !texts.isEmpty {
            parts.append("Visible text: \(texts.prefix(8).joined(separator: " / "))")
        }
        return parts.joined(separator: ". ")
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

private struct GeneratedPayload: Encodable {
    let validated_a2ui_json: [ServerMessage]
    let summary: String
}

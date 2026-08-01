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
public struct GenerateA2UITool: TurnEndingTool, TranscriptAwareTool {
    /// 副エージェントの呼び出し方をホストから注入する。
    ///
    /// - Parameters:
    ///   - prompt: 組み立て済みのシステムプロンプト。
    ///   - attempt: 1 始まりの試行回数（ログ・観測用）。
    ///   - transcript: 実行時点の会話（進行中の `generate_a2ui` 呼び出しは除去済み）。
    ///     副エージェントの LLM 呼び出しにそのまま渡す — 同一 run 内で取得したツール結果
    ///     （検索結果等）が見えないと、モデルはデータを捏造する。
    /// - Returns: `render_a2ui` の引数。ツール呼び出しが得られなければ `nil`。
    public typealias Invoke = @Sendable (
        _ prompt: String,
        _ attempt: Int,
        _ transcript: [LLMMessage]
    ) async throws -> RenderA2UIArguments?

    /// 生成されたメッセージ列を検証する（ホストのカタログ・allowlist を適用する）。
    public typealias Validate = @Sendable ([AgentMessage]) -> [String]

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

    /// トランスクリプトなしの実行（`Tool` 要件）。
    ///
    /// ループランタイムが `TranscriptAwareTool` に対応していれば呼ばれない。
    /// 会話文脈なしでは副エージェントがデータを捏造しやすいため、空トランスクリプトで委譲する。
    public func execute(with argumentsData: Data) async throws -> ToolResult {
        try await execute(with: argumentsData, transcript: [])
    }

    public func execute(with argumentsData: Data, transcript: [LLMMessage]) async throws -> ToolResult {
        let args = GenerateArgs(argumentsData: argumentsData)

        // 進行中の generate_a2ui 呼び出しを剥がす（Strands 方式の条件付き除去）。
        // 対応する結果のない toolUse はプロバイダに拒否され、副エージェントは
        // このツールを持っていない。
        let conversation = Self.strippingInFlightCall(from: transcript, toolName: toolName)

        // intent=update: 過去に描画したサーフェスをトランスクリプトから復元する
        // （公式 findPriorSurface 相当）。見つからなければエラーをモデルに返して
        // 自己修正させる（公式と同じ帰結）。
        var editContext: A2UISubagentPrompt.EditContext?
        if args.isUpdate, let targetSurfaceId = args.targetSurfaceId {
            guard let prior = Self.findPriorSurface(in: conversation, surfaceId: targetSurfaceId) else {
                return .error(
                    "intent='update' requested target_surface_id='\(targetSurfaceId)'"
                        + " but no prior render of that surface was found in conversation history"
                )
            }
            editContext = A2UISubagentPrompt.EditContext(prior: prior, changes: args.changes)
        }
        let basePrompt = prompt.render(editContext: editContext)

        let result = try await runner.run(
            basePrompt: basePrompt,
            invoke: { prompt, attempt in try await invoke(prompt, attempt, conversation) },
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
        // 生の operations がそのままツール結果として履歴に残り、更新時はここから
        // 過去サーフェスを復元する。
        return .json(try JSONEncoder().encode(OperationsEnvelope(a2ui_operations: result.messages)))
    }

    /// 進行中（結果未着）の自ツール呼び出しを含む末尾メッセージを剥がす。
    ///
    /// ミラー元: Strands アダプタの `stripInFlightToolCall`。LangGraph の無条件
    /// `slice(0, -1)` ではなく、「末尾が assistant で、かつ自ツール名の toolUse を含む」
    /// ときだけ剥がす — ループ構造次第で末尾がツールコールとは限らず、無条件除去は
    /// ユーザー発話を落とすリスクがあるため。
    static func strippingInFlightCall(from transcript: [LLMMessage], toolName: String) -> [LLMMessage] {
        guard let last = transcript.last,
              last.role == .assistant,
              last.toolUses.contains(where: { $0.name == toolName }) else {
            return transcript
        }
        return Array(transcript.dropLast())
    }

    /// トランスクリプトのツール結果から、対象サーフェスの直近の描画状態を復元する。
    ///
    /// ミラー元: `@ag-ui/a2ui-toolkit` の `findPriorSurface`。ツール結果メッセージを
    /// **新しい順**に走査し、`a2ui_operations` エンベロープを含むものからサーフェス状態を
    /// 組み立てる。メッセージ内のオペレーションは**前方向**に評価する（レンダラと同じ
    /// document 順。delete の後の create は復活）。最新メッセージで delete で終わっていたら
    /// 見つからなかったものとして扱う（もう表示されていないサーフェスを復活させない）。
    static func findPriorSurface(in transcript: [LLMMessage], surfaceId: String) -> A2UIPriorSurface? {
        var componentsJSON: String?
        var dataJSON: String?

        for message in transcript.reversed() {
            for result in message.toolResults.reversed() {
                guard case .success(let content) = result.content,
                      let envelope = try? JSONDecoder().decode(
                          OperationsEnvelope.self, from: Data(content.utf8)
                      ) else {
                    continue
                }

                var seenComponents: String?
                var seenData: String?
                var deleted = false
                for operation in envelope.a2ui_operations {
                    switch operation {
                    case .createSurface(let cs) where cs.surfaceId == surfaceId:
                        deleted = false
                    case .updateComponents(let uc) where uc.surfaceId == surfaceId:
                        deleted = false
                        seenComponents = Self.encodeJSON(uc.components)
                    case .updateDataModel(let udm) where udm.surfaceId == surfaceId:
                        deleted = false
                        if let value = udm.value {
                            seenData = Self.encodeJSON(value)
                        }
                    case .deleteSurface(let ds) where ds.surfaceId == surfaceId:
                        deleted = true
                        seenComponents = nil
                        seenData = nil
                    default:
                        break
                    }
                }

                // このメッセージが対象サーフェスに触れていなければ次へ
                guard seenComponents != nil || seenData != nil || deleted else { continue }

                // 最新の言及が delete なら、そのサーフェスはもう存在しない
                if deleted, componentsJSON == nil, dataJSON == nil {
                    return nil
                }
                // 新しいメッセージの値が勝ち、古いメッセージは未設定フィールドだけを埋める
                if componentsJSON == nil { componentsJSON = seenComponents }
                if dataJSON == nil { dataJSON = seenData }
                if componentsJSON != nil, dataJSON != nil {
                    return A2UIPriorSurface(
                        surfaceId: surfaceId, componentsJSON: componentsJSON!, dataJSON: dataJSON
                    )
                }
            }
        }

        guard let componentsJSON else { return nil }
        return A2UIPriorSurface(surfaceId: surfaceId, componentsJSON: componentsJSON, dataJSON: dataJSON)
    }

    private static func encodeJSON(_ value: some Encodable) -> String? {
        guard let data = try? JSONEncoder().encode(value) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    /// `render_a2ui` の引数を A2UI メッセージ列へ変換する。
    ///
    /// `catalogId` はホスト固定。`surfaceId` はモデル出力が untrusted なので空文字を弾き、
    /// 更新時は `surfaceIdOverride`（プランナーが指定した対象）を優先する。
    static func messages(
        from args: RenderA2UIArguments,
        catalogId: String,
        surfaceIdOverride: String? = nil
    ) -> [AgentMessage] {
        let resolved = surfaceIdOverride ?? args.surfaceId
        let surfaceId = resolved.isEmpty ? A2UISubagentConstants.defaultSurfaceId : resolved
        var messages: [AgentMessage] = [
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
/// Decodable も備える — `findPriorSurface` が過去のツール結果からこの形を読み戻す。
struct OperationsEnvelope: Codable {
    let a2ui_operations: [AgentMessage]
}

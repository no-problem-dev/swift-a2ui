import A2UICore
import Foundation
import LLMClient
import LLMTool
import StructuredDataCore

/// 外側ツール — メインのプランナーが呼ぶ `generate_a2ui`。
///
/// ミラー元: `@ag-ui/a2ui-toolkit` の `generate_a2ui`。
///
/// 引数は `intent` だけで、**A2UI JSON を含まない**。メインは「UI を作れ」という意図しか
/// 表明できず、実際の JSON 生成は副エージェント（`RenderA2UITool` を強制呼び出しする
/// LLM リクエスト）が担う。これによりメインのシステムプロンプトから A2UI スキーマを外せ、
/// テキストへの JSON 流出も原理的に消える。
///
/// ## アペンドオンリー
///
/// このツールは **`createSurface` しか生成しない**。1 ターン = 新しい 1 サーフェスで、
/// 過去のサーフェスは書き換えない（会話ログのように積み上がる）。v1.0 の `createSurface` は
/// `components` / `dataModel` を同梱できるので、画面 1 枚が 1 メッセージで完結する。
///
/// A2UI にも AG-UI にも「この操作だけ許可する」という交渉の仕組みは無い。公式実装と同じく
/// **ツールの形そのもの**で縛る — 副エージェントに渡す `render_a2ui` の引数に操作の別が無く、
/// このツールが組み立てるのも `createSurface` 一択なので、更新や削除は表現できない。
/// 1 枚のキャンバスを更新し続ける用途が要るなら、別のツールとして足す。
///
/// `catalogId` と `surfaceId` はホストの所有物で、モデルは選べない。特に `surfaceId` は
/// 仕様上レンダラの生存期間で一意でなければならず（既存 id への再作成はエラー）、
/// モデル出力に任せると衝突しうるため毎回ホストが発行する。
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

    /// このターンのサーフェス ID を発行する。既定は UUID。
    ///
    /// 仕様がレンダラ生存期間での一意性を要求するため、モデルではなくホストが決める。
    /// テストが決定的な ID を使えるよう差し替え可能にしてある。
    public typealias MakeSurfaceId = @Sendable () -> String

    public let toolName: String
    private let catalogId: String
    private let prompt: A2UISubagentPrompt
    private let runner: A2UISubagentRunner
    private let invoke: Invoke
    private let validate: Validate
    private let makeSurfaceId: MakeSurfaceId

    public init(
        toolName: String = A2UISubagentConstants.generateToolName,
        catalogId: String,
        prompt: A2UISubagentPrompt,
        runner: A2UISubagentRunner = A2UISubagentRunner(),
        invoke: @escaping Invoke,
        validate: @escaping Validate,
        makeSurfaceId: @escaping MakeSurfaceId = { A2UISubagentConstants.newSurfaceId() }
    ) {
        self.toolName = toolName
        self.catalogId = catalogId
        self.prompt = prompt
        self.runner = runner
        self.invoke = invoke
        self.validate = validate
        self.makeSurfaceId = makeSurfaceId
    }

    public var toolDescription: String { A2UISubagentConstants.generateToolDescription }

    /// アペンドオンリーなので、対象サーフェスも変更内容も引数に無い。
    /// モデルが表明できるのは「何を描きたいか」だけ。
    public var inputSchema: JSONSchema {
        .object(
            properties: [
                "intent": .string(description: A2UISubagentConstants.GenerateArgDescriptions.intent),
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
        // 進行中の generate_a2ui 呼び出しを剥がす（Strands 方式の条件付き除去）。
        // 対応する結果のない toolUse はプロバイダに拒否され、副エージェントは
        // このツールを持っていない。
        let conversation = Self.strippingInFlightCall(from: transcript, toolName: toolName)

        // このターンのサーフェス。毎回新規で、過去のサーフェスには触れない。
        let surfaceId = makeSurfaceId()

        let result = try await runner.run(
            basePrompt: prompt.render(),
            invoke: { prompt, attempt in try await invoke(prompt, attempt, conversation) },
            buildMessages: { rendered in
                Self.messages(from: rendered, catalogId: catalogId, surfaceId: surfaceId)
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
        // 生の operations がそのままツール結果として履歴に残る。
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

    /// `render_a2ui` の引数を A2UI メッセージへ変換する。
    ///
    /// v1.0 の `createSurface` は `components` / `dataModel` を同梱できるので、**常に 1 通**。
    /// `updateComponents` / `updateDataModel` は生成しない — それがアペンドオンリーの実体で、
    /// 「createSurface だけを許可する」がツールの形で保証される。
    ///
    /// `catalogId` も `surfaceId` もホストが決める（モデル出力の `surfaceId` は使わない）。
    static func messages(
        from args: RenderA2UIArguments,
        catalogId: String,
        surfaceId: String
    ) -> [AgentMessage] {
        [
            .createSurface(CreateSurface(
                surfaceId: surfaceId,
                catalogId: catalogId,
                components: args.components,
                dataModel: args.data
            )),
        ]
    }

}

/// 公式 `wrapAsOperationsEnvelope` と同じエンベロープ形。
struct OperationsEnvelope: Codable {
    let a2ui_operations: [AgentMessage]
}

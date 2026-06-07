import A2ACore
import A2UIA2A
import A2UIAgentTool
import A2UICore
import A2UIPrompt
import A2UITyped
import Foundation
import LLMClient
import LLMTool

/// presenter（コンテンツ提示）型 A2UI エージェントの自己記述一式。
///
/// 「役割（system prompt）・道具（tools）・プロトコル宣言（agent extension）・
/// 委譲説明（description）」を A2UI ドメインの SSOT としてこのパッケージが持ち、
/// ホストアプリは executor への注入と、言語・モデル選択などのドメイン判断だけを行う。
///
/// カタログ・手本を含む UI の全知識はこのエージェントに閉じる。生成は公式
/// `send_a2ui_json_to_client` ツール一本（公式 rizzcharts 準拠: スキーマと手本は
/// ツールが所有し、アタッチ時に system prompt へ同伴）。
public enum A2UIPresenterAgent {
    public static let defaultName = "a2ui"

    /// オーケストレータが委譲判断に使う説明（card / ルーティング用）。
    /// 「内容は全部渡す・サーフェスは毎ターン更新し続ける」を card 段階で明示する —
    /// 1 回きりの最終工程として読ませない。
    public static let defaultDescription =
        "Renders content as an interactive A2UI surface on the user's screen. Send it the complete "
        + "content to display — it cannot see other agents' replies. Once a surface exists, every "
        + "answer must be sent to it again to update the surface."

    /// presenter の UI 規約（サーフェスのライフサイクルと品質基準）。
    /// `systemPrompt` の `## UI Description:` セクションに入る。
    public static let uiDescription = """
    - The surface root fills the host frame: use a full-width container (e.g. Column with "align":"stretch") \
    as the component with id "root", not a Card. Use Card only for sub-sections inside a surface.
    - Maintain a SINGLE surface for the whole conversation: reuse the same surfaceId every \
    turn and update it in place with updateComponents / updateDataModel. Do not create additional surfaces.
    - Compose the answer as a data-model-driven A2UI surface, matching the richness and quality of the example \
    below: put dynamic values in the data model and reference them with {"path":"/..."} bindings. On the FIRST \
    paint of a surface, send the full component tree and a single updateDataModel at "/". \
    The example is the quality bar and the source of the reusable patterns — reuse them, but choose the structure \
    and components that fit THIS request instead of copying it verbatim.
    - When updating an EXISTING surface, send the smallest change that realizes it: updateDataModel at the \
    narrowest path(s) that changed (e.g. "/problem", "/items"). Send updateComponents ONLY when the visual \
    structure itself changes — never resend an unchanged component tree. Your earlier A2UI messages in this \
    conversation are the current surface state: diff against them, and never blindly overwrite values the user edited.
    - Keep it interactive across turns: when an action event arrives (e.g. a "followup" carrying an "ask"), treat \
    it as the user's next request and respond by updating the surface, refreshing any \
    "next" suggestions to match the new content.
    """

    /// a2ui ワーカーの system prompt（役割 + UI 規約 + ワークフロー規則）。
    ///
    /// presenter サブセットの pruning 済みスキーマと手本サーフェスはツール
    /// （`SendA2UIToClientTool`）が所有しアタッチ時に同伴するため、ここには指示だけを持つ。
    public static func systemPrompt(language: String = "Japanese") -> SystemPrompt {
        var role = SystemPrompt {
            PromptComponent.role("You are an A2UI agent. Render the content given to you as A2UI surface(s) on the user's screen.")
            PromptComponent.note("All user-facing text you produce must be written in \(language).")
            PromptComponent.outputConstraint("Your final output MUST be an A2UI UI rendered as JSON messages — never reply with plain prose only.")
        }.render()
        // 公式 rizzcharts の role 末尾文（逐語）: ツール使用を MUST で指示する。
        role += "\nYou MUST use the `\(A2UIToolConstants.toolName)` tool with the "
            + "`\(A2UIToolConstants.jsonArgName)` argument set to the A2UI JSON payload to send to the client."
        let instruction = A2UIPromptBuilder.presenter().buildSystemPrompt(
            role: role,
            workflowRules: A2UIWorkflowRules.toolCall + "\n" + A2UIWorkflowRules.scopeRules + "\n"
                + A2UIWorkflowRules.basicCatalogRules + "\n" + A2UIWorkflowRules.textMathRules,
            uiDescription: uiDescription,
            includeSchema: false
        )
        return SystemPrompt(stringLiteral: instruction)
    }

    /// a2ui ワーカーの公式ツール一式（生成は `send_a2ui_json_to_client` 一本）。
    /// presenter サブセットの pruning 済みスキーマと手本サーフェスはツールが所有し、
    /// アタッチ時に system prompt へ同伴する（公式 rizzcharts 準拠）。
    public static func tools() -> [any Tool] {
        [
            SendA2UIToClientTool<BasicCatalog>(
                examples: A2UIExampleFormatter.format(
                    name: "REFERENCE SURFACE EXAMPLE",
                    content: A2UIExample.presenterSurface()
                ),
                promptBuilder: .presenter()
            )
        ]
    }

    /// card で宣言する A2UI プロトコル拡張（対応カタログの自己申告）。
    /// カタログネゴシエーションはプロトコル層の責務 — LLM プロンプトには入れない。
    public static func agentExtension() -> AgentExtension {
        A2UIExtension.agentExtension(supportedCatalogIds: [BasicCatalog.catalogId])
    }

    /// ホスト（オーケストレータ）の出力指示に足す、a2ui への委譲必須の制約。
    /// a2ui がいる編成では毎ターン a2ui への委譲を必須にする — プレーンテキスト即答の裁量は残さない。
    public static func hostOutputConstraint(agentName: String = defaultName) -> PromptComponent {
        .outputConstraint(
            "Every turn, including follow-ups, must end by sending the complete answer content to the "
                + "`\(agentName)` agent; then reply with one short sentence. Never answer in plain text only.")
    }
}

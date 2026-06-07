import Foundation
import Testing
import A2UIAgent
import A2UIA2A
import A2UICore
import A2UIPrompt
import A2UITyped
import LLMClient

@Suite("A2UIPresenterAgent (presenter エージェントの自己記述)")
struct A2UIPresenterAgentTests {

    @Test("system prompt は役割・ツール強制・規則・UI 規約を持ち、スキーマと手本は持たない")
    func systemPromptSections() {
        let rendered = A2UIPresenterAgent.systemPrompt().render()
        #expect(rendered.contains("You are an A2UI agent."))
        #expect(rendered.contains("You MUST use the `\(A2UIToolConstants.toolName)` tool"))
        #expect(rendered.contains("## Workflow Description:"))
        #expect(rendered.contains(A2UIWorkflowRules.scopeRules))
        #expect(rendered.contains("## UI Description:"))
        #expect(rendered.contains("Maintain a SINGLE surface"))
        #expect(rendered.contains("written in Japanese"))
        // スキーマと手本はツールが所有し同伴する — system prompt 本体には含まれない。
        #expect(!rendered.contains(SchemaBlockFormatter.beginMarker))
        #expect(!rendered.contains("REFERENCE SURFACE EXAMPLE"))
    }

    @Test("言語は引数で差し替えられる")
    func languageParameter() {
        let rendered = A2UIPresenterAgent.systemPrompt(language: "English").render()
        #expect(rendered.contains("written in English"))
        #expect(!rendered.contains("written in Japanese"))
    }

    @Test("tools は公式ツール一本で、presenter スキーマと手本を同伴する")
    func toolsCarrySchemaAndExample() throws {
        let tools = A2UIPresenterAgent.tools()
        #expect(tools.count == 1)
        let tool = try #require(tools.first)
        #expect(tool.toolName == A2UIToolConstants.toolName)
        let instruction = try #require(tool.systemInstruction)
        #expect(instruction.contains(SchemaBlockFormatter.beginMarker))
        #expect(instruction.contains("REFERENCE SURFACE EXAMPLE"))
        // presenter pruning: カタログは提示用 9 コンポーネントに絞られている。
        #expect(instruction.contains("\"Card\""))
        #expect(!instruction.contains("\"Tabs\""))
        #expect(!instruction.contains("\"Modal\""))
    }

    @Test("agent extension は basic catalog を宣言する")
    func agentExtensionDeclaresCatalog() {
        let ext = A2UIPresenterAgent.agentExtension()
        #expect(ext.uri == A2UIExtension.uri)
        let ids = ext.params?[A2UIExtension.supportedCatalogIdsKey]?.arrayValue?.compactMap(\.stringValue)
        #expect(ids == [BasicCatalog.catalogId])
    }

    @Test("ホスト側の委譲必須制約はエージェント名を埋め込む")
    func hostOutputConstraintEmbedsAgentName() {
        let rendered = SystemPrompt { A2UIPresenterAgent.hostOutputConstraint() }.render()
        #expect(rendered.contains("`\(A2UIPresenterAgent.defaultName)` agent"))
        #expect(rendered.contains("Never answer in plain text only."))

        let custom = SystemPrompt { A2UIPresenterAgent.hostOutputConstraint(agentName: "renderer") }.render()
        #expect(custom.contains("`renderer` agent"))
    }
}

import Foundation
import Testing
import A2UIAgent
import A2UIA2A
import A2UICatalog
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

// コンポーネントパレットの差し替え（tools(components:)）— pruning・手本・検証が
// 同じ集合で同期することを固定する。
@Suite("A2UIPresenterAgent (component palette)")
struct A2UIPresenterAgentPaletteTests {

    private func instruction(components: Set<String>) throws -> String {
        let tools = A2UIPresenterAgent.tools(components: components)
        let tool = try #require(tools.first)
        return try #require(tool.systemInstruction)
    }

    @Test("デフォルトは presenter 9 種")
    func defaultPalette() {
        #expect(A2UIPresenterAgent.defaultComponents == A2UIExample.presenterComponentNames)
    }

    @Test("フルカタログ指定でスキーマに全 18 種 + フルパレット手本が同伴する")
    func fullCatalogPalette() throws {
        let inst = try instruction(components: BasicComponent.componentNames)
        #expect(inst.contains("\"Tabs\""))
        #expect(inst.contains("\"Modal\""))
        #expect(inst.contains("\"DateTimeInput\""))
        // フルパレットの手本は referenceSurface（Tabs / Modal / フォーム入力を含む）
        #expect(inst.contains("REFERENCE SURFACE EXAMPLE"))
        #expect(inst.contains("mapModal"))
    }

    @Test("presenter を包含する拡張パレットはスキーマ拡張 + presenter 手本を保つ")
    func supersetKeepsPresenterExample() throws {
        let inst = try instruction(components: A2UIExample.presenterComponentNames.union(["Slider"]))
        #expect(inst.contains("\"Slider\""))
        #expect(!inst.contains("\"Modal\""))
        #expect(inst.contains("REFERENCE SURFACE EXAMPLE"))
        #expect(!inst.contains("mapModal"))  // presenterSurface であって referenceSurface ではない
    }

    @Test("presenter パレットを欠く集合では矛盾する手本を同伴しない")
    func reducedPaletteDropsExample() throws {
        let inst = try instruction(components: ["Column", "Row", "Text"])
        #expect(inst.contains("\"Text\""))
        #expect(!inst.contains("\"Card\""))
        #expect(!inst.contains("REFERENCE SURFACE EXAMPLE"))
    }

    @Test("正規化: カタログ外の名前は落ち、空になればデフォルトへフォールバック")
    func sanitization() {
        #expect(A2UIPresenterAgent.sanitizedComponents(["Text", "Frobnicate"]) == ["Text"])
        #expect(A2UIPresenterAgent.sanitizedComponents(["Frobnicate"]) == A2UIPresenterAgent.defaultComponents)
        #expect(A2UIPresenterAgent.sanitizedComponents([]) == A2UIPresenterAgent.defaultComponents)
    }

    @Test("exampleSurface の 3 分岐")
    func exampleSelection() {
        #expect(A2UIPresenterAgent.exampleSurface(for: BasicComponent.componentNames) == A2UIExample.referenceSurface())
        #expect(A2UIPresenterAgent.exampleSurface(for: A2UIExample.presenterComponentNames) == A2UIExample.presenterSurface())
        #expect(A2UIPresenterAgent.exampleSurface(for: ["Column", "Text"]) == nil)
    }
}

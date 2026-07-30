import Foundation
import Testing
@testable import A2UICore
@testable import A2UISubagent
import LLMTool
import StructuredDataCore

private func componentsValue(_ json: String) -> [StructuredValue] {
    (try? JSONParser().parse(Data(json.utf8)))?.arrayValue ?? []
}

/// 同期クロージャから使えるスレッドセーフな失敗カウンタ（1 回目だけ失敗させる）。
private final class FailureCounter: @unchecked Sendable {
    private let lock = NSLock()
    private var count = 0

    func shouldFail() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        count += 1
        return count == 1
    }
}

private let validComponents = componentsValue("""
[{"id":"root","component":"Column","children":["t"]},{"id":"t","component":"Text","text":"こんにちは"}]
""")

@Suite("A2UISubagentPrompt")
struct A2UISubagentPromptTests {

    @Test("セクション順序は 生成 → デザイン → カタログ → コンポジション")
    func sectionOrder() {
        let prompt = A2UISubagentPrompt(
            guidelines: A2UIGuidelines(composition: "COMPOSITION"),
            catalogSchema: "CATALOG"
        ).render()

        let generationIndex = try! #require(prompt.range(of: "A2UI Protocol Instructions")).lowerBound
        let designIndex = try! #require(prompt.range(of: "## Design Guidelines")).lowerBound
        let catalogIndex = try! #require(prompt.range(of: "## Available Components")).lowerBound
        let compositionIndex = try! #require(prompt.range(of: "COMPOSITION")).lowerBound
        #expect(generationIndex < designIndex)
        #expect(designIndex < catalogIndex)
        #expect(catalogIndex < compositionIndex)
    }

    @Test("render ツール名がガイドラインに埋め込まれる")
    func embedsRenderToolName() {
        let prompt = A2UISubagentPrompt(renderToolName: "custom_render").render()
        #expect(prompt.contains("You MUST call the custom_render tool"))
    }

    @Test("suppressed のブロックは出力されない")
    func suppressesBlocks() {
        let prompt = A2UISubagentPrompt(
            guidelines: A2UIGuidelines(generation: .suppressed, design: .suppressed),
            catalogSchema: "CATALOG"
        ).render()
        #expect(!prompt.contains("A2UI Protocol Instructions"))
        #expect(!prompt.contains("## Design Guidelines"))
        #expect(prompt.contains("## Available Components"))
    }

    @Test("custom のブロックは差し替わる")
    func replacesBlocks() {
        let prompt = A2UISubagentPrompt(
            guidelines: A2UIGuidelines(design: .custom("DELISH THEME"))
        ).render()
        #expect(prompt.contains("## Design Guidelines\nDELISH THEME"))
        #expect(!prompt.contains("Create polished, visually appealing"))
    }

    @Test("編集コンテキストは末尾に付き、変更要求も載る")
    func appendsEditContext() {
        let prompt = A2UISubagentPrompt(catalogSchema: "CATALOG").render(
            editContext: A2UISubagentPrompt.EditContext(
                prior: A2UIPriorSurface(
                    surfaceId: "s1",
                    componentsJSON: #"[{"id":"root"}]"#,
                    dataJSON: #"{"items":[]}"#
                ),
                changes: "2 番目のカードを赤に"
            )
        )
        #expect(prompt.contains("## Editing an existing surface"))
        #expect(prompt.contains("You are editing surface 's1'"))
        #expect(prompt.contains("### Previous components"))
        #expect(prompt.contains("### Previous data"))
        #expect(prompt.contains("### Requested changes\n2 番目のカードを赤に"))
        // 末尾セクションであること
        let catalogIndex = try! #require(prompt.range(of: "## Available Components")).lowerBound
        let editIndex = try! #require(prompt.range(of: "## Editing an existing surface")).lowerBound
        #expect(catalogIndex < editIndex)
    }
}

@Suite("RenderA2UIArguments — untrusted なモデル出力の narrow")
struct RenderA2UIArgumentsTests {

    @Test("正常な引数を取り出す")
    func parsesValidArguments() throws {
        let data = Data(#"{"surfaceId":"s1","components":[{"id":"root","component":"Text","text":"hi"}],"data":{"items":[]}}"#.utf8)
        let args = try #require(RenderA2UIArguments(argumentsData: data))
        #expect(args.surfaceId == "s1")
        #expect(args.components.count == 1)
        #expect(args.data != nil)
    }

    @Test("components が無ければ nil")
    func rejectsMissingComponents() {
        #expect(RenderA2UIArguments(argumentsData: Data(#"{"surfaceId":"s1"}"#.utf8)) == nil)
    }

    @Test("surfaceId が数値・欠落でも落ちず空文字になる（フォールバックに委ねる）")
    func narrowsNonStringSurfaceId() throws {
        let numeric = try #require(RenderA2UIArguments(argumentsData: Data(#"{"surfaceId":42,"components":[]}"#.utf8)))
        #expect(numeric.surfaceId.isEmpty)
        let missing = try #require(RenderA2UIArguments(argumentsData: Data(#"{"components":[]}"#.utf8)))
        #expect(missing.surfaceId.isEmpty)
    }

    @Test("data が配列・null ならデータモデル無しとして扱う")
    func narrowsNonObjectData() throws {
        let arrayData = try #require(RenderA2UIArguments(argumentsData: Data(#"{"surfaceId":"s","components":[],"data":[1]}"#.utf8)))
        #expect(arrayData.data == nil)
    }
}

@Suite("GenerateA2UITool")
struct GenerateA2UIToolTests {

    private func tool(
        maxAttempts: Int = 3,
        invoke: @escaping GenerateA2UITool.Invoke,
        validate: @escaping GenerateA2UITool.Validate = { _ in [] }
    ) -> GenerateA2UITool {
        GenerateA2UITool(
            catalogId: "https://example.com/catalogs/delish/v1/catalog.json",
            prompt: A2UISubagentPrompt(catalogSchema: "CATALOG"),
            runner: A2UISubagentRunner(maxAttempts: maxAttempts),
            invoke: invoke,
            validate: validate
        )
    }

    @Test("引数スキーマに A2UI JSON は含まれない（意図のみ）")
    func schemaCarriesIntentOnly() throws {
        let subject = tool(invoke: { _, _ in nil })
        let encoded = String(decoding: try JSONEncoder().encode(subject.inputSchema), as: UTF8.self)
        #expect(encoded.contains("intent"))
        #expect(encoded.contains("target_surface_id"))
        #expect(encoded.contains("changes"))
        #expect(!encoded.contains("components"))
        #expect(!encoded.contains("a2ui_json"))
    }

    @Test("成功時は公式のエンベロープ形（a2ui_operations）で返す")
    func buildsOperationsEnvelope() async throws {
        let subject = tool(invoke: { _, _ in
            RenderA2UIArguments(surfaceId: "s1", components: validComponents, data: nil)
        })
        let result = try await subject.execute(with: Data("{}".utf8))
        #expect(!result.isError)
        let payload = result.stringValue
        #expect(payload.contains(A2UISubagentConstants.operationsKey))
        #expect(payload.contains("createSurface"))
        #expect(payload.contains("updateComponents"))
        // catalogId はホスト固定（モデルは選べない）。JSONEncoder は / をエスケープする
        #expect(payload.contains(#"catalogs\/delish\/v1\/catalog.json"#))
    }

    @Test("intent=update は対象サーフェス ID を維持する（モデルが別 ID を返しても上書きしない）")
    func keepsTargetSurfaceIdOnUpdate() async throws {
        let subject = tool(invoke: { _, _ in
            RenderA2UIArguments(surfaceId: "model-invented", components: validComponents, data: nil)
        })
        let result = try await subject.execute(
            with: Data(#"{"intent":"update","target_surface_id":"existing-surface"}"#.utf8)
        )
        #expect(result.stringValue.contains("existing-surface"))
        #expect(!result.stringValue.contains("model-invented"))
    }

    @Test("surfaceId が空ならフォールバック ID を使う")
    func fallsBackToDefaultSurfaceId() async throws {
        let subject = tool(invoke: { _, _ in
            RenderA2UIArguments(surfaceId: "", components: validComponents, data: nil)
        })
        let result = try await subject.execute(with: Data("{}".utf8))
        #expect(result.stringValue.contains(A2UISubagentConstants.defaultSurfaceId))
    }

    @Test("検証エラーは次の試行のプロンプトに fix-it として載る")
    func retriesWithValidationFeedback() async throws {
        actor Recorder {
            var prompts: [String] = []
            private var validations = 0
            func record(_ prompt: String) { prompts.append(prompt) }
            /// 1 回目だけ検証を失敗させる。
            func failFirstValidation() -> Bool {
                validations += 1
                return validations == 1
            }
        }
        let recorder = Recorder()
        // validate は同期クロージャなので nonisolated な参照カウンタで判定する
        let failures = FailureCounter()
        let subject = tool(
            invoke: { prompt, _ in
                await recorder.record(prompt)
                return RenderA2UIArguments(surfaceId: "s1", components: validComponents, data: nil)
            },
            validate: { _ in failures.shouldFail() ? ["component 'Foo' is not allowed"] : [] }
        )
        let result = try await subject.execute(with: Data("{}".utf8))
        #expect(!result.isError)

        let prompts = await recorder.prompts
        #expect(prompts.count == 2)
        #expect(!prompts[0].contains("Previous attempt was invalid"))
        #expect(prompts[1].contains("## Previous attempt was invalid — fix these and regenerate:"))
        #expect(prompts[1].contains("- component 'Foo' is not allowed"))
        // 追記は蓄積せず basePrompt から作り直す
        #expect(prompts[1].components(separatedBy: "Previous attempt was invalid").count == 2)
    }

    @Test("試行を使い切るとツールエラー（recovery_exhausted）")
    func exhaustsRetries() async throws {
        let subject = tool(
            maxAttempts: 2,
            invoke: { _, _ in RenderA2UIArguments(surfaceId: "s1", components: validComponents, data: nil) },
            validate: { _ in ["still invalid"] }
        )
        let result = try await subject.execute(with: Data("{}".utf8))
        #expect(result.isError)
        #expect(result.stringValue.contains(A2UISubagentConstants.recoveryExhaustedCode))
        #expect(result.stringValue.contains("2 attempt(s)"))
    }

    @Test("ツール呼び出しが得られない場合も試行として数え、最後はエラー")
    func handlesMissingToolCall() async throws {
        let subject = tool(maxAttempts: 2, invoke: { _, _ in nil })
        let result = try await subject.execute(with: Data("{}".utf8))
        #expect(result.isError)
        #expect(result.stringValue.contains("did not call \(A2UISubagentConstants.renderToolName)"))
    }

    @Test("intent=update は編集コンテキストをプロンプトに載せる")
    func passesUpdateIntentToPrompt() async throws {
        actor Recorder {
            var prompt = ""
            func record(_ value: String) { prompt = value }
        }
        let recorder = Recorder()
        let subject = tool(invoke: { prompt, _ in
            await recorder.record(prompt)
            return RenderA2UIArguments(surfaceId: "s1", components: validComponents, data: nil)
        })
        _ = try await subject.execute(
            with: Data(#"{"intent":"update","target_surface_id":"s1","changes":"色を変える"}"#.utf8)
        )
        let prompt = await recorder.prompt
        #expect(prompt.contains("## Editing an existing surface"))
        #expect(prompt.contains("You are editing surface 's1'"))
        #expect(prompt.contains("色を変える"))
    }
}

@Suite("A2UISubagentRunner")
struct A2UISubagentRunnerTests {

    @Test("検証を通った試行は再試行しない")
    func stopsOnFirstValidAttempt() async throws {
        var invocations = 0
        let result = try await A2UISubagentRunner(maxAttempts: 3).run(
            basePrompt: "BASE",
            invoke: { _, _ in
                invocations += 1
                return RenderA2UIArguments(surfaceId: "s", components: validComponents, data: nil)
            },
            buildMessages: { _ in [.createSurface(CreateSurface(surfaceId: "s", catalogId: "c"))] },
            validate: { _ in [] }
        )
        #expect(invocations == 1)
        #expect(result.ok)
        #expect(result.attempts.count == 1)
    }

    @Test("fix-it の追記形式は - 始まりの行")
    func formatsIssuesAsBullets() {
        let augmented = A2UISubagentRunner.augment("BASE", with: ["a", "b"])
        #expect(augmented.hasPrefix("BASE\n\n## Previous attempt was invalid"))
        #expect(augmented.contains("- a\n- b"))
    }

    @Test("問題が無ければプロンプトは変えない")
    func leavesPromptUnchangedWhenValid() {
        #expect(A2UISubagentRunner.augment("BASE", with: []) == "BASE")
    }
}

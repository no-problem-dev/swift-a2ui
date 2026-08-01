import Foundation
import Testing
@testable import A2UICore
@testable import A2UISubagent
import LLMClient
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

    @Test("freeform: components が JSON 文字列でもパースする（Gemini の自由記述）")
    func parsesFreeformComponents() throws {
        let data = Data(#"""
        {"surfaceId":"s1","components":"[{\"id\":\"root\",\"component\":\"Text\",\"text\":\"hi\"}]","data":"{\"items\":[1]}"}
        """#.utf8)
        let args = try #require(RenderA2UIArguments(argumentsData: data))
        #expect(args.surfaceId == "s1")
        #expect(args.components.count == 1)
        #expect(args.components[0]["component"].stringValue == "Text")
        #expect(args.data?["items"].arrayValue?.count == 1)
    }

    @Test("freeform: コードフェンス・末尾カンマ・スマートクォートを修復する")
    func healsFreeformComponents() throws {
        let payload = "```json\n[{\u{201C}id\u{201D}:\"root\",\"component\":\"Text\",\"text\":\"hi\",},]\n```"
        let encoded = try JSONEncoder().encode(["surfaceId": "s1", "components": payload])
        let args = try #require(RenderA2UIArguments(argumentsData: encoded))
        #expect(args.components.count == 1)
        #expect(args.components[0]["id"].stringValue == "root")
    }

    @Test("freeform: 単一オブジェクトは配列にラップする")
    func wrapsSingleObjectInFreeform() throws {
        let data = Data(#"{"surfaceId":"s1","components":"{\"id\":\"root\",\"component\":\"Text\"}"}"#.utf8)
        let args = try #require(RenderA2UIArguments(argumentsData: data))
        #expect(args.components.count == 1)
    }

    @Test("freeform: 修復不能な components は nil（検証器に弾かせてリトライへ）")
    func rejectsUnfixableFreeform() {
        let data = Data(#"{"surfaceId":"s1","components":"not json at all {{{"}"#.utf8)
        #expect(RenderA2UIArguments(argumentsData: data) == nil)
    }

    @Test("freeform: data が '{}' ならデータモデル無し")
    func treatsEmptyObjectStringAsNoData() throws {
        let data = Data(#"{"surfaceId":"s1","components":"[{\"id\":\"root\",\"component\":\"Text\"}]","data":"{}"}"#.utf8)
        let args = try #require(RenderA2UIArguments(argumentsData: data))
        #expect(args.data == nil)
    }
}

@Suite("RenderA2UITool — 宣言形")
struct RenderA2UIToolShapeTests {

    @Test("typed は components を配列として宣言する")
    func typedDeclaresArray() throws {
        let schema = RenderA2UITool(payloadShape: .typed).inputSchema
        let encoded = String(decoding: try JSONEncoder().encode(schema), as: UTF8.self)
        #expect(encoded.contains(#""components":{"#))
        #expect(encoded.contains(#""type":"array""#))
    }

    @Test("freeform は components/data を文字列として宣言する")
    func freeformDeclaresStrings() throws {
        let schema = RenderA2UITool(payloadShape: .freeform).inputSchema
        let encoded = String(decoding: try JSONEncoder().encode(schema), as: UTF8.self)
        #expect(!encoded.contains(#""type":"array""#))
        // surfaceId / components / data すべて string
        #expect(encoded.contains("JSON string"))
    }

    @Test("既定は typed（公式共有定義と同じ）")
    func defaultsToTyped() {
        #expect(RenderA2UITool().payloadShape == .typed)
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
        let subject = tool(invoke: { _, _, _ in nil })
        let encoded = String(decoding: try JSONEncoder().encode(subject.inputSchema), as: UTF8.self)
        #expect(encoded.contains("intent"))
        #expect(encoded.contains("target_surface_id"))
        #expect(encoded.contains("changes"))
        #expect(!encoded.contains("components"))
        #expect(!encoded.contains("a2ui_json"))
    }

    @Test("成功時は公式のエンベロープ形（a2ui_operations）で返す")
    func buildsOperationsEnvelope() async throws {
        let subject = tool(invoke: { _, _, _ in
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
        let subject = tool(invoke: { _, _, _ in
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
        let subject = tool(invoke: { _, _, _ in
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
            invoke: { prompt, _, _ in
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
            invoke: { _, _, _ in RenderA2UIArguments(surfaceId: "s1", components: validComponents, data: nil) },
            validate: { _ in ["still invalid"] }
        )
        let result = try await subject.execute(with: Data("{}".utf8))
        #expect(result.isError)
        #expect(result.stringValue.contains(A2UISubagentConstants.recoveryExhaustedCode))
        #expect(result.stringValue.contains("2 attempt(s)"))
    }

    @Test("ツール呼び出しが得られない場合も試行として数え、最後はエラー")
    func handlesMissingToolCall() async throws {
        let subject = tool(maxAttempts: 2, invoke: { _, _, _ in nil })
        let result = try await subject.execute(with: Data("{}".utf8))
        #expect(result.isError)
        #expect(result.stringValue.contains("did not call \(A2UISubagentConstants.renderToolName)"))
    }

    @Test("intent=update は履歴から過去サーフェスを復元してプロンプトに載せる")
    func passesUpdateIntentToPrompt() async throws {
        actor Recorder {
            var prompt = ""
            func record(_ value: String) { prompt = value }
        }
        let recorder = Recorder()
        let subject = tool(invoke: { prompt, _, _ in
            await recorder.record(prompt)
            return RenderA2UIArguments(surfaceId: "s1", components: validComponents, data: nil)
        })
        // 過去に s1 を描画したツール結果を含むトランスクリプト
        let priorEnvelope = #"{"a2ui_operations":[{"version":"v1.0","createSurface":{"surfaceId":"s1","catalogId":"c"}},{"version":"v1.0","updateComponents":{"surfaceId":"s1","components":[{"id":"root","component":"Text","text":"旧テキスト"}]}}]}"#
        let transcript: [LLMMessage] = [
            .user("表示して"),
            .toolUses([(id: "g1", name: A2UISubagentConstants.generateToolName, input: Data("{}".utf8))]),
            .toolResults([(toolCallId: "g1", name: A2UISubagentConstants.generateToolName, content: .success(priorEnvelope))]),
        ]
        _ = try await subject.execute(
            with: Data(#"{"intent":"update","target_surface_id":"s1","changes":"色を変える"}"#.utf8),
            transcript: transcript
        )
        let prompt = await recorder.prompt
        #expect(prompt.contains("## Editing an existing surface"))
        #expect(prompt.contains("You are editing surface 's1'"))
        #expect(prompt.contains("旧テキスト"))
        #expect(prompt.contains("色を変える"))
    }

    @Test("intent=update で過去サーフェスが見つからなければエラー（モデルに自己修正させる）")
    func updateWithoutPriorSurfaceErrors() async throws {
        let subject = tool(invoke: { _, _, _ in
            Issue.record("subagent should not be invoked")
            return nil
        })
        let result = try await subject.execute(
            with: Data(#"{"intent":"update","target_surface_id":"missing"}"#.utf8),
            transcript: [.user("hi")]
        )
        #expect(result.isError)
        #expect(result.stringValue.contains("no prior render"))
    }

    @Test("副エージェントには進行中の generate_a2ui 呼び出しを剥がした会話が渡る")
    func stripsInFlightCallFromConversation() async throws {
        actor Recorder {
            var transcript: [LLMMessage] = []
            func record(_ value: [LLMMessage]) { transcript = value }
        }
        let recorder = Recorder()
        let subject = tool(invoke: { _, _, conversation in
            await recorder.record(conversation)
            return RenderA2UIArguments(surfaceId: "s1", components: validComponents, data: nil)
        })
        let transcript: [LLMMessage] = [
            .user("鶏むね肉"),
            .toolUses([(id: "s1", name: "search_recipes", input: Data("{}".utf8))]),
            .toolResults([(toolCallId: "s1", name: "search_recipes", content: .success(#"{"recipes":[{"id":"207505149046817824"}]}"#))]),
            .toolUses([(id: "g1", name: A2UISubagentConstants.generateToolName, input: Data("{}".utf8))]),
        ]
        _ = try await subject.execute(with: Data("{}".utf8), transcript: transcript)

        let conversation = await recorder.transcript
        // 末尾の未解決 generate_a2ui 呼び出しは剥がされる
        #expect(conversation.count == 3)
        // 先に完了した検索の結果（本物のレシピ ID）は残る
        #expect("\(conversation.map(\.contents))".contains("207505149046817824"))
    }
}

@Suite("GenerateA2UITool — strip / findPriorSurface")
struct GenerateA2UIToolHistoryTests {

    @Test("末尾が自ツールの未解決呼び出しのときだけ剥がす（Strands 方式）")
    func stripsOnlyOwnInFlightCall() {
        let generate = A2UISubagentConstants.generateToolName
        let inFlight: [LLMMessage] = [
            .user("hi"),
            .toolUses([(id: "g1", name: generate, input: Data("{}".utf8))]),
        ]
        #expect(GenerateA2UITool.strippingInFlightCall(from: inFlight, toolName: generate).count == 1)

        // 末尾がユーザー発話なら剥がさない
        let userTail: [LLMMessage] = [.user("hi")]
        #expect(GenerateA2UITool.strippingInFlightCall(from: userTail, toolName: generate).count == 1)

        // 末尾が別ツールの呼び出しなら剥がさない
        let otherTool: [LLMMessage] = [
            .user("hi"),
            .toolUses([(id: "x1", name: "search_recipes", input: Data("{}".utf8))]),
        ]
        #expect(GenerateA2UITool.strippingInFlightCall(from: otherTool, toolName: generate).count == 2)
    }

    @Test("findPriorSurface は新しい順に探索し、最新の状態を返す")
    func findsMostRecentSurfaceState() throws {
        let older = #"{"a2ui_operations":[{"version":"v1.0","createSurface":{"surfaceId":"s1","catalogId":"c"}},{"version":"v1.0","updateComponents":{"surfaceId":"s1","components":[{"id":"root","component":"Text","text":"v1"}]}}]}"#
        let newer = #"{"a2ui_operations":[{"version":"v1.0","updateComponents":{"surfaceId":"s1","components":[{"id":"root","component":"Text","text":"v2"}]}}]}"#
        let transcript: [LLMMessage] = [
            .toolResults([(toolCallId: "a", name: "generate_a2ui", content: .success(older))]),
            .toolResults([(toolCallId: "b", name: "generate_a2ui", content: .success(newer))]),
        ]
        let prior = try #require(GenerateA2UITool.findPriorSurface(in: transcript, surfaceId: "s1"))
        #expect(prior.componentsJSON.contains("v2"))
        #expect(!prior.componentsJSON.contains("v1"))
    }

    @Test("最新の言及が deleteSurface なら見つからない（消えたサーフェスを復活させない）")
    func deletedSurfaceIsNotFound() {
        let created = #"{"a2ui_operations":[{"version":"v1.0","createSurface":{"surfaceId":"s1","catalogId":"c"}},{"version":"v1.0","updateComponents":{"surfaceId":"s1","components":[{"id":"root","component":"Text","text":"v1"}]}}]}"#
        let deleted = #"{"a2ui_operations":[{"version":"v1.0","deleteSurface":{"surfaceId":"s1"}}]}"#
        let transcript: [LLMMessage] = [
            .toolResults([(toolCallId: "a", name: "generate_a2ui", content: .success(created))]),
            .toolResults([(toolCallId: "b", name: "generate_a2ui", content: .success(deleted))]),
        ]
        #expect(GenerateA2UITool.findPriorSurface(in: transcript, surfaceId: "s1") == nil)
    }

    @Test("同一メッセージ内で delete の後の create は復活（document 順評価）")
    func deleteThenCreateInSameMessageRevives() throws {
        let payload = #"{"a2ui_operations":[{"version":"v1.0","deleteSurface":{"surfaceId":"s1"}},{"version":"v1.0","createSurface":{"surfaceId":"s1","catalogId":"c"}},{"version":"v1.0","updateComponents":{"surfaceId":"s1","components":[{"id":"root","component":"Text","text":"revived"}]}}]}"#
        let transcript: [LLMMessage] = [
            .toolResults([(toolCallId: "a", name: "generate_a2ui", content: .success(payload))]),
        ]
        let prior = try #require(GenerateA2UITool.findPriorSurface(in: transcript, surfaceId: "s1"))
        #expect(prior.componentsJSON.contains("revived"))
    }

    @Test("エラー結果と無関係な JSON は無視する")
    func ignoresErrorsAndUnrelatedResults() {
        let transcript: [LLMMessage] = [
            .toolResults([(toolCallId: "a", name: "generate_a2ui", content: .failure("boom"))]),
            .toolResults([(toolCallId: "b", name: "search_recipes", content: .success(#"{"recipes":[]}"#))]),
        ]
        #expect(GenerateA2UITool.findPriorSurface(in: transcript, surfaceId: "s1") == nil)
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

@Suite("A2UIOperationsExtractor")
struct A2UIOperationsExtractorTests {
    private let envelope = #"{"a2ui_operations":[{"version":"v1.0","createSurface":{"surfaceId":"s1","catalogId":"c"}}]}"#

    @Test("generate_a2ui の成功結果から operations を取り出す")
    func extractsFromSuccess() throws {
        let messages = try #require(A2UIOperationsExtractor.messages(
            fromToolResult: A2UISubagentConstants.generateToolName, output: envelope, isError: false
        ))
        #expect(messages.count == 1)
    }

    @Test("エラー結果は破棄する")
    func discardsErrors() {
        #expect(A2UIOperationsExtractor.messages(
            fromToolResult: A2UISubagentConstants.generateToolName, output: envelope, isError: true
        ) == nil)
    }

    @Test("他ツールの結果は無視する")
    func ignoresOtherTools() {
        #expect(A2UIOperationsExtractor.messages(
            fromToolResult: "search_recipes", output: envelope, isError: false
        ) == nil)
    }

    @Test("カスタムツール名にも対応する")
    func honorsCustomToolName() throws {
        let messages = try #require(A2UIOperationsExtractor.messages(
            fromToolResult: "render_ui", output: envelope, isError: false, toolName: "render_ui"
        ))
        #expect(messages.count == 1)
    }
}

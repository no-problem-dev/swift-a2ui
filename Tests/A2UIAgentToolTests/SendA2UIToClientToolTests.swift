import Foundation
import Testing
@testable import A2UIAgentTool
import A2UICore
import A2UITyped
import LLMTool

private let validPayload = """
[{"version":"v0.10","createSurface":{"surfaceId":"s1","catalogId":"basic"}},\
{"version":"v0.10","updateComponents":{"surfaceId":"s1","components":[\
{"id":"root","component":"Column","children":["t"]},\
{"id":"t","component":"Text","text":"hi"}]}}]
"""

private let missingRootPayload = """
[{"version":"v0.10","createSurface":{"surfaceId":"s1","catalogId":"basic"}},\
{"version":"v0.10","updateComponents":{"surfaceId":"s1","components":[\
{"id":"orphan","component":"Text","text":"hi"}]}}]
"""

private func execute(a2uiJSON: String?) async throws -> ToolResult {
    struct Args: Encodable { let a2ui_json: String? }
    let tool = SendA2UIToClientTool<BasicCatalog>()
    let data = try JSONEncoder().encode(Args(a2ui_json: a2uiJSON))
    return try await tool.execute(with: data)
}

@Suite("SendA2UIToClientTool (port of _SendA2uiJsonToClientTool)")
struct SendA2UIToClientToolTests {

    @Test("公式準拠のツール名・説明・ターン終了契約")
    func declaration() {
        let tool = SendA2UIToClientTool<BasicCatalog>()
        #expect(tool.toolName == "send_a2ui_json_to_client")
        #expect(tool.toolDescription.contains("---BEGIN A2UI JSON SCHEMA---"))
        #expect((tool as Any) is any TurnEndingTool)
    }

    @Test("成功: validated_a2ui_json キーで検証済みペイロードを返す")
    func successReturnsValidatedJSON() async throws {
        let result = try await execute(a2uiJSON: validPayload)
        guard case .json(let data) = result else {
            Issue.record("expected .json, got \(result)"); return
        }
        struct Payload: Decodable { let validated_a2ui_json: [ServerMessage] }
        let payload = try JSONDecoder().decode(Payload.self, from: data)
        #expect(payload.validated_a2ui_json.count == 2)
    }

    @Test("引数欠落: missing required arg エラー")
    func missingArgumentIsError() async throws {
        let result = try await execute(a2uiJSON: nil)
        guard case .error(let message) = result else {
            Issue.record("expected .error, got \(result)"); return
        }
        #expect(message.hasPrefix("Failed to call A2UI tool send_a2ui_json_to_client:"))
        #expect(message.contains("missing required arg a2ui_json"))
    }

    @Test("不正 JSON: Failed to parse JSON エラー")
    func unparsablePayloadIsError() async throws {
        let result = try await execute(a2uiJSON: "not json {{{")
        guard case .error(let message) = result else {
            Issue.record("expected .error, got \(result)"); return
        }
        #expect(message.contains("Failed to parse JSON"))
    }

    @Test("カタログ検証失敗はエラー（root 欠落）")
    func validationFailureIsError() async throws {
        let result = try await execute(a2uiJSON: missingRootPayload)
        guard case .error(let message) = result else {
            Issue.record("expected .error, got \(result)"); return
        }
        #expect(message.hasPrefix("Failed to call A2UI tool send_a2ui_json_to_client:"))
    }
}

@Suite("A2UIToolResultExtractor (port of part_converter)")
struct A2UIToolResultExtractorTests {

    @Test("成功結果から ServerMessage を抽出")
    func extractsMessagesFromSuccess() async throws {
        let result = try await execute(a2uiJSON: validPayload)
        let messages = A2UIToolResultExtractor.messages(
            fromToolResult: "send_a2ui_json_to_client",
            output: result.stringValue,
            isError: false
        )
        #expect(messages?.count == 2)
    }

    @Test("エラー結果はドロップ（nil）")
    func dropsErrorResults() {
        let messages = A2UIToolResultExtractor.messages(
            fromToolResult: "send_a2ui_json_to_client",
            output: "Error: Failed to call A2UI tool",
            isError: true
        )
        #expect(messages == nil)
    }

    @Test("他ツールの結果は無視（nil）")
    func ignoresOtherTools() {
        let messages = A2UIToolResultExtractor.messages(
            fromToolResult: "send_message",
            output: #"{"validated_a2ui_json": []}"#,
            isError: false
        )
        #expect(messages == nil)
    }
}

// promptBuilder の許可セット（プロンプト側プルーニング）が検証にも適用されることを固定する —
// モデルに提示していないコンポーネントはツールエラーとなり、同一ループ内で自己修正される。
@Suite("SendA2UIToClientTool (promptBuilder allowlist enforcement)")
struct SendA2UIToClientToolAllowlistTests {

    private let sliderPayload = """
    [{"version":"v0.10","createSurface":{"surfaceId":"s1","catalogId":"basic"}},\
    {"version":"v0.10","updateComponents":{"surfaceId":"s1","components":[\
    {"id":"root","component":"Column","children":["sl"]},\
    {"id":"sl","component":"Slider","value":3,"max":10}]}}]
    """

    private func execute(_ tool: SendA2UIToClientTool<BasicCatalog>, a2uiJSON: String) async throws -> ToolResult {
        struct Args: Encodable { let a2ui_json: String }
        return try await tool.execute(with: try JSONEncoder().encode(Args(a2ui_json: a2uiJSON)))
    }

    @Test("プルーニング済み promptBuilder は許可外コンポーネントをツールエラーで弾く")
    func prunedBuilderRejectsDisallowedComponent() async throws {
        let tool = SendA2UIToClientTool<BasicCatalog>(promptBuilder: .presenter())
        let result = try await execute(tool, a2uiJSON: sliderPayload)
        guard case .error(let message) = result else {
            Issue.record("expected .error, got \(result)"); return
        }
        #expect(message.contains("component 'Slider' (id: sl) is not allowed"))
    }

    @Test("デフォルト promptBuilder（プルーニングなし）はフルカタログを許可する")
    func defaultBuilderAcceptsFullCatalog() async throws {
        let tool = SendA2UIToClientTool<BasicCatalog>()
        let result = try await execute(tool, a2uiJSON: sliderPayload)
        guard case .json = result else {
            Issue.record("expected .json, got \(result)"); return
        }
    }
}

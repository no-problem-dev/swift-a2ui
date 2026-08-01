import Foundation
import Testing

@testable import A2UIPrompt

/// `Spec/v1_0/` は上流仕様の逐語コピーで、出荷する `Sources/A2UIPrompt/Resources/` はその同じ実体
/// でなければならない（→ `Spec/VENDORING.md`）。
///
/// ここでは「LLM に配るスキーマが本当に v1.0 の上流スキーマか」を固定する。バージョンを上げ忘れた
/// まま出荷する、v0.9 のコピーが紛れる、といった drift をビルドで落とすのが目的。
/// 3 つのコピーがバイト一致していること自体は `Spec/VENDORING.md` の手順と CI の diff で担保する。
@Suite("Vendored spec integrity")
struct VendoredSpecIntegrityTests {

    private func shipped(_ json: String) throws -> [String: Any] {
        try #require(JSONSerialization.jsonObject(with: Data(json.utf8)) as? [String: Any])
    }

    @Test("the shipped agent_to_renderer schema is upstream v1.0")
    func agentToRendererIsUpstreamV1() throws {
        let schema = try shipped(A2UIPromptBuilder.bundledAgentToRendererJSON())
        #expect(
            schema["$id"] as? String
                == "https://a2ui.org/specification/v1_0/agent_to_renderer.json")

        // Every message envelope must pin version v1.0 — a stale copy fails right here.
        let defs = try #require(schema["$defs"] as? [String: Any])
        let messageNames = defs.keys.filter { $0.hasSuffix("Message") }.sorted()
        #expect(
            messageNames == [
                "ActionResponseMessage", "CallFunctionMessage", "CreateSurfaceMessage",
                "DeleteSurfaceMessage", "UpdateComponentsMessage", "UpdateDataModelMessage",
            ])
        for name in messageNames {
            let properties = (defs[name] as? [String: Any])?["properties"] as? [String: Any]
            let version = properties?["version"] as? [String: Any]
            #expect(version?["const"] as? String == "v1.0", "\(name) is not stamped v1.0")
        }
    }

    @Test("the shipped common_types schema is upstream v1.0")
    func commonTypesIsUpstreamV1() throws {
        let schema = try shipped(A2UIPromptBuilder.bundledCommonTypesJSON())
        #expect(schema["$id"] as? String == "https://a2ui.org/specification/v1_0/common_types.json")

        let defs = try #require(schema["$defs"] as? [String: Any])
        // Types v1.0 introduced — their absence means the copy predates v1.0.
        #expect(defs["Child"] != nil)
        #expect(defs["FunctionCommon"] != nil)
        #expect(defs["IndexSystemFunction"] != nil)

        // v1.0 moved callableFrom/returnType off the wire and added catalogId for mixing.
        let functionCall = try #require(defs["FunctionCall"] as? [String: Any])
        let properties = try #require(functionCall["properties"] as? [String: Any])
        #expect(properties["catalogId"] != nil)
        #expect(properties["callableFrom"] == nil)
        #expect(properties["returnType"] == nil)
    }
}

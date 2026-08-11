import Foundation
import Testing
import A2ACore
import A2UICore
@testable import A2UIA2A

/// `[Part].a2uiExtraction()` / `StreamResponse.a2uiExtraction()` の検証。
/// A2A のストリーム/パートから A2UI メッセージを取り出す（A2UI でないパートは無視、
/// A2UI を名乗って壊れているパートは `failures` として報告する）。
@Suite("A2UI stream extraction")
struct A2UIStreamTests {
    private func message(_ id: String = "surface_1") -> AgentMessage {
        .createSurface(CreateSurface(surfaceId: id, catalogId: "https://example.com/catalog.json",
                                     dataModel: .object(["title": .string("hello")])))
    }

    @Test("parts から A2UI のみ抽出（text/plain data は無視）")
    func extractsFromParts() throws {
        let parts: [Part] = [
            .text("noise"),
            try .a2ui(message("s1")),
            .data(.object(["foo": .string("bar")])),
            try .a2ui(message("s2")),
        ]
        let extraction = parts.a2uiExtraction()
        #expect(extraction.messages.count == 2)
        #expect(!extraction.hasFailures)
        #expect(parts.containsA2UI)
    }

    /// 壊れたパートは抽出を止めない（寛容さは維持）が、黙って消えてはいけない。
    /// 「UI が無かった」と「UI が読めなかった」は呼び出し側の対応が正反対になる。
    @Test("壊れた A2UI パートは抽出を止めないが failures として報告される")
    func reportsMalformed() throws {
        // A2UI を名乗るが AgentMessage として壊れている data。
        let malformed = Part.data(.object(["nonsense": .bool(true)]),
                                  metadata: [A2UIMediaType.metadataKey: .string(A2UIMediaType.a2uiJSON)])
        let parts: [Part] = [malformed, try .a2ui(message("s1"))]
        let extraction = parts.a2uiExtraction()
        #expect(extraction.messages.count == 1) // 有効な1件は取り出せている
        #expect(extraction.failures.count == 1) // 壊れた1件は消えていない
        #expect(extraction.hasFailures)
    }

    /// A2UI がそもそも無いターンは failures も空 — 「静かなターン」と「壊れたターン」が区別できる。
    @Test("A2UI を含まないパート列は messages も failures も空")
    func quietTurnIsNotAFailure() {
        let extraction: A2UIPartExtraction = [Part.text("hi")].a2uiExtraction()
        #expect(extraction.messages.isEmpty)
        #expect(!extraction.hasFailures)
    }

    @Test("StreamResponse(task の artifact) から抽出")
    func extractsFromStreamResponseTask() throws {
        let task = A2ATask(
            id: TaskID("t"), contextId: ContextID("c"), status: TaskStatus(state: .working),
            artifacts: [Artifact(artifactId: ArtifactID("a"), parts: [try .a2ui(message())])]
        )
        let response = StreamResponse.task(task)
        #expect(response.containsA2UI)
        #expect(response.a2uiExtraction().messages.count == 1)
    }

    @Test("A2UI を含まない StreamResponse は空")
    func nonA2UIStreamResponse() {
        let response = StreamResponse.message(Message(messageId: MessageID("m"), role: .agent, parts: [.text("hi")]))
        #expect(!response.containsA2UI)
        #expect(response.a2uiExtraction().messages.isEmpty)
        #expect(!response.a2uiExtraction().hasFailures)
    }
}

import Foundation
import Testing
import A2ACore
import A2UICore
@testable import A2UIA2A

/// `[Part].a2uiServerMessages()` / `StreamResponse.a2uiServerMessages()` の検証。
/// A2A のストリーム/パートから A2UI メッセージを取り出す（A2UI でない/壊れたパートは無視）。
@Suite("A2UI stream extraction")
struct A2UIStreamTests {
    private func message(_ id: String = "surface_1") -> ServerMessage {
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
        let messages = parts.a2uiServerMessages()
        #expect(messages.count == 2)
        #expect(parts.containsA2UI)
    }

    @Test("壊れた A2UI パートは握りつぶす（抽出を止めない）")
    func skipsMalformed() throws {
        // A2UI を名乗るが ServerMessage として壊れている data。
        let malformed = Part.data(.object(["nonsense": .bool(true)]),
                                  metadata: [A2UIMediaType.metadataKey: .string(A2UIMediaType.a2uiJSON)])
        let parts: [Part] = [malformed, try .a2ui(message("s1"))]
        #expect(parts.a2uiServerMessages().count == 1) // 壊れた方は除外、有効な1件だけ
    }

    @Test("StreamResponse(task の artifact) から抽出")
    func extractsFromStreamResponseTask() throws {
        let task = A2ATask(
            id: TaskID("t"), contextId: ContextID("c"), status: TaskStatus(state: .working),
            artifacts: [Artifact(artifactId: ArtifactID("a"), parts: [try .a2ui(message())])]
        )
        let response = StreamResponse.task(task)
        #expect(response.containsA2UI)
        #expect(response.a2uiServerMessages().count == 1)
    }

    @Test("A2UI を含まない StreamResponse は空")
    func nonA2UIStreamResponse() {
        let response = StreamResponse.message(Message(messageId: MessageID("m"), role: .agent, parts: [.text("hi")]))
        #expect(!response.containsA2UI)
        #expect(response.a2uiServerMessages().isEmpty)
    }
}

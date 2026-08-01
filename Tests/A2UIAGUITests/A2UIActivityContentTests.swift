import A2UICore
import AGUICore
import Foundation
import Testing

@testable import A2UIAGUI

struct A2UIActivityContentTests {
    private func decodeSnapshot(_ json: String) throws -> ActivitySnapshotEvent {
        guard case .activitySnapshot(let snapshot) = try JSONDecoder().decode(AGUIEvent.self, from: Data(json.utf8)) else {
            throw AGUIError("expected ACTIVITY_SNAPSHOT")
        }
        return snapshot
    }

    /// paint 判別: `a2ui_operations` が配列(公式 recovery-gate テスト規範)。
    @Test func paintSnapshotDecodesOperations() throws {
        let json = """
        {"type":"ACTIVITY_SNAPSHOT","messageId":"a2ui-surface-c1","activityType":"a2ui-surface","replace":true,
         "content":{"a2ui_operations":[
            {"version":"v1.0","createSurface":{"surfaceId":"s1","catalogId":"delish"}},
            {"version":"v1.0","updateComponents":{"surfaceId":"s1","components":[
                {"id":"root","componentType":"Text","properties":{"text":{"literalString":"hi"}}}
            ]}}
         ]}}
        """
        let content = try A2UIActivityContent(snapshot: decodeSnapshot(json))
        guard case .paint(let operations) = content else {
            Issue.record("expected paint")
            return
        }
        #expect(operations.count == 2)
        guard case .createSurface(let create) = operations[0] else {
            Issue.record("expected createSurface")
            return
        }
        #expect(create.surfaceId == "s1")
    }

    /// lifecycle 判別: `status` が文字列。
    @Test func lifecycleSnapshotDecodesStatus() throws {
        let json = """
        {"type":"ACTIVITY_SNAPSHOT","messageId":"a2ui-surface-c1","activityType":"a2ui-surface","replace":true,
         "content":{"status":"retrying","attempt":2,"maxAttempts":3,
                    "errors":[{"code":"no_root","path":"/components","message":"missing root"}]}}
        """
        let content = try A2UIActivityContent(snapshot: decodeSnapshot(json))
        guard case .lifecycle(let lifecycle) = content else {
            Issue.record("expected lifecycle")
            return
        }
        #expect(lifecycle.kind == .retrying)
        #expect(lifecycle.attempt == 2)
        #expect(lifecycle.errors?.first?.code == "no_root")
    }

    /// 未知の status も受理する(前方互換)。
    @Test func unknownLifecycleStatusIsTolerated() throws {
        let content = try A2UIActivityContent(content: .object(["status": .string("queued")]))
        guard case .lifecycle(let lifecycle) = content else {
            Issue.record("expected lifecycle")
            return
        }
        #expect(lifecycle.kind == nil)
        #expect(lifecycle.status == "queued")
    }

    @Test func wrongActivityTypeIsRejected() {
        let snapshot = ActivitySnapshotEvent(messageId: "m", activityType: "other", content: .object([:]))
        #expect(throws: AGUIError.self) {
            _ = try A2UIActivityContent(snapshot: snapshot)
        }
    }

    @Test func contentWithNeitherFormIsRejected() {
        #expect(throws: AGUIError.self) {
            _ = try A2UIActivityContent(content: .object(["something": .bool(true)]))
        }
    }

    // MARK: - サーバー側ビルダー

    @Test func paintBuilderRoundTrips() throws {
        let operations: [AgentMessage] = [
            .createSurface(CreateSurface(surfaceId: "s1", catalogId: "delish")),
            .updateComponents(UpdateComponents(surfaceId: "s1", components: [])),
        ]
        let snapshot = try ActivitySnapshotEvent.a2uiPaint(messageId: "a2ui-surface-c1", operations: operations)
        #expect(snapshot.replace == true)
        #expect(snapshot.activityType == A2UIAGUIConstants.activityType)
        let decoded = try A2UIActivityContent(snapshot: snapshot)
        #expect(decoded == .paint(operations))
    }

    /// 禁則: createSurface 単独 emit(components 同梱必須)。
    @Test func paintBuilderRejectsCreateSurfaceAlone() {
        #expect(throws: AGUIError.self) {
            _ = try ActivitySnapshotEvent.a2uiPaint(
                messageId: "m",
                operations: [.createSurface(CreateSurface(surfaceId: "s1", catalogId: "delish"))]
            )
        }
        #expect(throws: AGUIError.self) {
            _ = try ActivitySnapshotEvent.a2uiPaint(messageId: "m", operations: [])
        }
    }

    @Test func lifecycleBuilderRoundTrips() throws {
        let snapshot = try ActivitySnapshotEvent.a2uiLifecycle(
            messageId: "a2ui-surface-c1",
            .building(progressTokens: 40)
        )
        let decoded = try A2UIActivityContent(snapshot: snapshot)
        guard case .lifecycle(let lifecycle) = decoded else {
            Issue.record("expected lifecycle")
            return
        }
        #expect(lifecycle.kind == .building)
        #expect(lifecycle.progressTokens == 40)
    }

    @Test func messageIdStrategies() {
        #expect(A2UIAGUIConstants.surfaceMessageId(toolCallId: "c1") == "a2ui-surface-c1")
        #expect(A2UIAGUIConstants.surfaceMessageId(surfaceId: "s1", toolCallId: "c1") == "a2ui-surface-s1-c1")
    }
}

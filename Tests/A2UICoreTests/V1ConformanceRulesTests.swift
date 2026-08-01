import Foundation
import Testing

@testable import A2UICore

/// UAX #31 の識別子規則（A2UI v1.0 §Catalog entity naming）。
/// 例は仕様本文の Valid / Invalid リストをそのまま使う。
@Suite("v1.0 catalog identifier rules (UAX #31)")
struct CatalogIdentifierTests {

    @Test("the spec's valid examples pass", arguments: [
        "UserProfileCard", "submit_form", "item_id_1", "_internal_state",
    ])
    func validExamples(_ identifier: String) {
        #expect(CatalogIdentifier.isValid(identifier))
    }

    @Test("the spec's invalid examples are rejected", arguments: [
        "User Card",    // Pattern_White_Space
        "1stItem",      // leading Nd
        "submit-form",  // Pattern_Syntax
        "user#name",
        "calc$val",
    ])
    func invalidExamples(_ identifier: String) {
        #expect(!CatalogIdentifier.isValid(identifier))
    }

    @Test("an empty identifier is invalid")
    func emptyIsInvalid() {
        #expect(!CatalogIdentifier.isValid(""))
    }

    /// XID_Start は ASCII に限らない — 非 ASCII のカタログ名も許される。
    @Test("non-ASCII identifiers are allowed when they satisfy XID")
    func nonASCIIAllowed() {
        #expect(CatalogIdentifier.isValid("レシピカード"))
        #expect(CatalogIdentifier.isValid("café_item"))
    }

    @Test("invalidIdentifiers reports only the offenders")
    func reportsOffenders() {
        #expect(
            CatalogIdentifier.invalidIdentifiers(in: ["Text", "submit-form", "Row", "1st"])
                == ["submit-form", "1st"])
    }
}

/// 実行境界の検証（A2UI v1.0 §Processing rules）。
/// v1.0 は callableFrom をワイヤーから外し、レンダラがカタログを引いて実行時に判定する。
@Suite("v1.0 function execution boundary")
struct FunctionBoundaryTests {

    private func call(_ name: String) -> CallFunctionMessage {
        CallFunctionMessage(functionCallId: "call-1", callFunction: FunctionCall(call: name))
    }

    @Test("agentOnly and rendererOrAgent accept an agent-initiated call")
    func acceptsAllowedBoundaries() {
        #expect(FunctionBoundary.acceptsAgentCall(name: "ping", callableFrom: .agentOnly))
        #expect(FunctionBoundary.acceptsAgentCall(name: "ping", callableFrom: .rendererOrAgent))
    }

    @Test("rendererOnly is rejected — the agent may not invoke it")
    func rejectsRendererOnly() {
        #expect(!FunctionBoundary.acceptsAgentCall(name: "validate", callableFrom: .rendererOnly))
        let error = FunctionBoundary.validateAgentCall(call("validate"), callableFrom: .rendererOnly)
        #expect(error?.code == "INVALID_FUNCTION_CALL")
        #expect(error?.functionCallId == "call-1")
        #expect(error?.message.contains("rendererOnly") == true)
    }

    /// 未登録も同じコードで拒否する（仕様: "or if the function is not registered at all").
    @Test("an unregistered function is rejected with the same code")
    func rejectsUnregistered() {
        #expect(!FunctionBoundary.acceptsAgentCall(name: "nope", callableFrom: nil))
        let error = FunctionBoundary.validateAgentCall(call("nope"), callableFrom: nil)
        #expect(error?.code == "INVALID_FUNCTION_CALL")
        #expect(error?.message.contains("not registered") == true)
    }

    @Test("an accepted call produces no error")
    func acceptedCallHasNoError() {
        #expect(FunctionBoundary.validateAgentCall(call("ping"), callableFrom: .agentOnly) == nil)
    }

    /// 拒否は renderer→agent の `error` メッセージとしてそのまま送れる形であること。
    @Test("the rejection encodes as a renderer error message")
    func rejectionEncodes() throws {
        let error = try #require(
            FunctionBoundary.validateAgentCall(call("validate"), callableFrom: .rendererOnly))
        let data = try JSONEncoder().encode(RendererMessage.error(error))
        let obj = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        #expect(obj["version"] as? String == "v1.0")
        let body = obj["error"] as! [String: Any]
        #expect(body["code"] as? String == "INVALID_FUNCTION_CALL")
        #expect(body["functionCallId"] as? String == "call-1")
    }
}

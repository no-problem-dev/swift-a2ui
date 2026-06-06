import Foundation
import Testing

@testable import A2UICore

// MARK: - v0.10 official test-case corpus (golden)

/// Decodes the official `specification/v0_10/test/cases/*.json` corpus through the Swift wire types.
///
/// Each case is `{description, valid, data}`. Our types do **structural decoding**, not full
/// JSON-Schema validation, so the contract we pin is: every `valid: true` message MUST decode and
/// round-trip. `valid: false` cases are only asserted where the failure is structural (a missing
/// *required* field our `Codable` enforces); pure schema constraints (e.g. surfaceId-XOR-callId) are
/// intentionally not enforced by the lenient Swift types and are skipped.
@Suite("v0.10 official test-case corpus")
struct V010CorpusTests {

    private struct CaseFile {
        let schema: String
        let cases: [(description: String, valid: Bool, data: Data)]
    }

    private func load(_ name: String) throws -> CaseFile {
        let url = Bundle.module.url(forResource: name, withExtension: "json", subdirectory: "Fixtures")!
        let root = try JSONSerialization.jsonObject(with: Data(contentsOf: url)) as! [String: Any]
        let schema = root["schema"] as! String
        let cases = try (root["tests"] as! [[String: Any]]).map {
            (description: $0["description"] as! String,
             valid: $0["valid"] as! Bool,
             data: try JSONSerialization.data(withJSONObject: $0["data"]!))
        }
        return CaseFile(schema: schema, cases: cases)
    }

    /// Required structural keys our Codable enforces, per message kind — used to assert that the
    /// matching `valid: false` cases (which omit one of these) actually fail to decode.
    private func hasStructuralOmission(_ data: Data) -> Bool {
        guard let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return false }
        if let cf = obj["callFunction"] as? [String: Any] {
            return obj["functionCallId"] == nil || cf["call"] == nil
        }
        if let fr = obj["functionResponse"] as? [String: Any] {
            return fr["functionCallId"] == nil || fr["call"] == nil || fr["value"] == nil
        }
        return false
    }

    @Test("all valid server→client messages decode and round-trip", arguments: [
        "case_call_function_message", "case_initial_state_validation",
    ])
    func serverMessages(_ file: String) throws {
        let cf = try load(file)
        #expect(cf.schema == "server_to_client.json")
        for c in cf.cases where c.valid {
            let decoded = try JSONDecoder().decode(ServerMessage.self, from: c.data)
            let reencoded = try JSONEncoder().encode(decoded)
            let redecoded = try JSONDecoder().decode(ServerMessage.self, from: reencoded)
            #expect(decoded == redecoded, "round-trip mismatch: \(c.description)")
        }
    }

    @Test("all valid client→server messages decode and round-trip", arguments: [
        "case_function_response", "case_client_messages",
    ])
    func clientMessages(_ file: String) throws {
        let cf = try load(file)
        #expect(cf.schema == "client_to_server.json")
        for c in cf.cases where c.valid {
            let decoded = try JSONDecoder().decode(ClientMessage.self, from: c.data)
            let reencoded = try JSONEncoder().encode(decoded)
            let redecoded = try JSONDecoder().decode(ClientMessage.self, from: reencoded)
            #expect(decoded == redecoded, "round-trip mismatch: \(c.description)")
        }
    }

    @Test("structurally-invalid messages fail to decode")
    func structuralFailures() throws {
        for file in ["case_call_function_message", "case_function_response"] {
            let cf = try load(file)
            let isServer = cf.schema == "server_to_client.json"
            for c in cf.cases where !c.valid && hasStructuralOmission(c.data) {
                #expect(throws: (any Error).self, "should reject: \(c.description)") {
                    if isServer { _ = try JSONDecoder().decode(ServerMessage.self, from: c.data) }
                    else { _ = try JSONDecoder().decode(ClientMessage.self, from: c.data) }
                }
            }
        }
    }
}

// MARK: - v0.10 new message types (focused)

@Suite("v0.10 CallFunctionMessage / FunctionResponse")
struct V010FunctionMessageTests {

    @Test func callFunctionMessageRoundTrip() throws {
        let msg: ServerMessage = .callFunction(CallFunctionMessage(
            functionCallId: "call-1",
            callFunction: FunctionCall(call: "pingServer", returnType: .void, callableFrom: .remoteOnly),
            wantResponse: true
        ))
        let data = try JSONEncoder().encode(msg)
        // The new message is flat: functionCallId / wantResponse / callFunction sit beside version.
        let obj = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        #expect(obj["version"] as? String == "v0.10")
        #expect(obj["functionCallId"] as? String == "call-1")
        #expect((obj["callFunction"] as! [String: Any])["callableFrom"] as? String == "remoteOnly")

        let decoded = try JSONDecoder().decode(ServerMessage.self, from: data)
        guard case .callFunction(let cfm) = decoded else { Issue.record("expected .callFunction"); return }
        #expect(cfm.functionCallId == "call-1")
        #expect(cfm.wantResponse == true)
        #expect(cfm.callFunction.callableFrom == .remoteOnly)
        #expect(cfm.callFunction.call == "pingServer")
    }

    @Test func functionResponseRoundTrip() throws {
        let msg: ClientMessage = .functionResponse(FunctionResponse(
            functionCallId: "call-1", call: "pingServer", value: .string("pong")
        ))
        let data = try JSONEncoder().encode(msg)
        let decoded = try JSONDecoder().decode(ClientMessage.self, from: data)
        guard case .functionResponse(let fr) = decoded else { Issue.record("expected .functionResponse"); return }
        #expect(fr.functionCallId == "call-1")
        #expect(fr.value == .string("pong"))
    }
}

@Suite("v0.10 ActionResponseMessage")
struct V010ActionResponseTests {

    @Test func valueResponseRoundTrip() throws {
        let msg: ServerMessage = .actionResponse(ActionResponseMessage(
            actionId: "act-1", actionResponse: .value(.object(["ok": .bool(true)]))
        ))
        let data = try JSONEncoder().encode(msg)
        let obj = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        #expect(obj["actionId"] as? String == "act-1")
        let decoded = try JSONDecoder().decode(ServerMessage.self, from: data)
        guard case .actionResponse(let arm) = decoded else { Issue.record("expected .actionResponse"); return }
        #expect(arm.actionId == "act-1")
        #expect(arm.actionResponse == .value(.object(["ok": .bool(true)])))
    }

    @Test func errorResponseRoundTrip() throws {
        let arm = ActionResponseMessage(actionId: "act-2", actionResponse: .error(code: "BOOM", message: "nope"))
        let data = try JSONEncoder().encode(ServerMessage.actionResponse(arm))
        let decoded = try JSONDecoder().decode(ServerMessage.self, from: data)
        guard case .actionResponse(let out) = decoded, case .error(let code, let message) = out.actionResponse else {
            Issue.record("expected .actionResponse(.error)"); return
        }
        #expect(code == "BOOM")
        #expect(message == "nope")
    }
}

// MARK: - v0.10 type additions

@Suite("v0.10 type additions")
struct V010TypeAdditionTests {

    @Test func eventActionWantResponseAndResponsePath() throws {
        let json = #"{"event":{"name":"recalc","wantResponse":true,"responsePath":"/total"}}"#
        let action = try JSONDecoder().decode(Action.self, from: Data(json.utf8))
        guard case .event(let e) = action else { Issue.record("expected .event"); return }
        #expect(e.wantResponse == true)
        #expect(e.responsePath == "/total")
    }

    @Test func functionCallCallableFromDecodes() throws {
        let json = #"{"call":"pingServer","returnType":"void","callableFrom":"clientOrRemote"}"#
        let fc = try JSONDecoder().decode(FunctionCall.self, from: Data(json.utf8))
        #expect(fc.callableFrom == .clientOrRemote)
    }

    @Test func userActionWantResponseAndActionId() throws {
        let ua = UserAction(name: "x", surfaceId: "s", sourceComponentId: "c",
                            timestamp: "2026-01-01T00:00:00Z", context: [:],
                            wantResponse: true, actionId: "a-1")
        let data = try JSONEncoder().encode(ClientMessage.action(ua))
        let decoded = try JSONDecoder().decode(ClientMessage.self, from: data)
        guard case .action(let out) = decoded else { Issue.record("expected .action"); return }
        #expect(out.wantResponse == true)
        #expect(out.actionId == "a-1")
    }

    @Test func createSurfaceCarriesInitialComponentsAndDataModel() throws {
        let json = """
        {"version":"v0.10","createSurface":{"surfaceId":"s","catalogId":"c",
         "components":[{"id":"root","component":"Text","text":"hi"}],
         "dataModel":{"user":{"name":"Jo"}}}}
        """
        let decoded = try JSONDecoder().decode(ServerMessage.self, from: Data(json.utf8))
        guard case .createSurface(let cs) = decoded else { Issue.record("expected .createSurface"); return }
        #expect(cs.components?.count == 1)
        #expect(cs.dataModel != nil)
    }

    @Test func clientErrorCorrelatesToFunctionCall() throws {
        let json = #"{"version":"v0.10","error":{"code":"FUNCTION_FAILED","functionCallId":"call-9","message":"boom"}}"#
        let decoded = try JSONDecoder().decode(ClientMessage.self, from: Data(json.utf8))
        guard case .error(let err) = decoded else { Issue.record("expected .error"); return }
        #expect(err.functionCallId == "call-9")
        #expect(err.surfaceId == nil)
    }
}

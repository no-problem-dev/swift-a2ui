import Testing
import Foundation
import A2UICore
import A2UICatalog
import A2UITyped
@testable import A2UITypedRenderer

@Suite("A2UIValidation (catalog validation before render)")
struct A2UIValidationTests {

    private func comp(_ json: String) -> StructuredValue {
        try! JSONDecoder().decode(StructuredValue.self, from: Data(json.utf8))
    }

    private func issues(_ messages: [ServerMessage]) -> [String] {
        A2UIValidation.issues(in: messages, for: BasicCatalog.self)
    }

    @Test("valid surface produces no issues")
    func validSurface() {
        let messages: [ServerMessage] = [
            .createSurface(CreateSurface(surfaceId: "s", catalogId: "basic")),
            .updateComponents(UpdateComponents(surfaceId: "s", components: [
                comp(#"{"id":"root","component":"Column","children":["t"]}"#),
                comp(#"{"id":"t","component":"Text","text":"hi"}"#),
            ])),
        ]
        #expect(issues(messages).isEmpty)
    }

    @Test("no surface or components is flagged")
    func noOutput() {
        #expect(issues([]) == ["no A2UI surface or components were produced"])
    }

    @Test("missing root is flagged")
    func missingRoot() {
        let messages: [ServerMessage] = [
            .updateComponents(UpdateComponents(surfaceId: "s", components: [
                comp(#"{"id":"t","component":"Text","text":"hi"}"#),
            ])),
        ]
        #expect(issues(messages).contains { $0.contains("root") })
    }

    @Test("unknown component name is flagged")
    func unknownComponent() {
        let messages: [ServerMessage] = [
            .updateComponents(UpdateComponents(surfaceId: "s", components: [
                comp(#"{"id":"root","component":"Column","children":["x"]}"#),
                comp(#"{"id":"x","component":"Frobnicate","value":1}"#),
            ])),
        ]
        #expect(issues(messages).contains { $0.contains("unknown component 'Frobnicate'") })
    }

    @Test("duplicate component id is flagged")
    func duplicateId() {
        let messages: [ServerMessage] = [
            .updateComponents(UpdateComponents(surfaceId: "s", components: [
                comp(#"{"id":"root","component":"Column","children":["root"]}"#),
                comp(#"{"id":"root","component":"Text","text":"dup"}"#),
            ])),
        ]
        #expect(issues(messages).contains { $0.contains("duplicate component id") })
    }

    @Test("malformed known component (Button without action) is flagged")
    func malformedKnown() {
        let messages: [ServerMessage] = [
            .updateComponents(UpdateComponents(surfaceId: "s", components: [
                comp(#"{"id":"root","component":"Column","children":["b"]}"#),
                comp(#"{"id":"b","component":"Button","child":"root"}"#),
            ])),
        ]
        #expect(issues(messages).contains { $0.contains("malformed component") })
    }
}

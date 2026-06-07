import Testing
import Foundation
import A2UICore
import A2UICatalog
@testable import A2UITyped

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

    @Test("missing root on first paint is flagged")
    func missingRoot() {
        let messages: [ServerMessage] = [
            .createSurface(CreateSurface(surfaceId: "s", catalogId: "basic")),
            .updateComponents(UpdateComponents(surfaceId: "s", components: [
                comp(#"{"id":"t","component":"Text","text":"hi"}"#),
            ])),
        ]
        #expect(issues(messages).contains { $0.contains("root") })
    }

    @Test("partial component update without root is valid for an existing surface")
    func partialUpdateWithoutRoot() {
        // createSurface がこのバッチに無い surface への updateComponents は差分更新 —
        // root はクライアント側に既にあるため必須にしない。
        let messages: [ServerMessage] = [
            .updateComponents(UpdateComponents(surfaceId: "existing", components: [
                comp(#"{"id":"extra","component":"Text","text":"appended"}"#),
            ])),
        ]
        #expect(issues(messages).isEmpty)
    }

    @Test("data-model-only batch is a valid incremental update")
    func dataModelOnlyBatch() {
        let messages: [ServerMessage] = [
            .updateDataModel(UpdateDataModel(surfaceId: "existing", path: "/", value: .object(["title": .string("更新")]))),
        ]
        #expect(issues(messages).isEmpty)
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

    @Test("duplicate createSurface without prior deleteSurface is flagged")
    func duplicateCreateSurface() {
        let messages: [ServerMessage] = [
            .createSurface(CreateSurface(surfaceId: "s", catalogId: "basic")),
            .updateComponents(UpdateComponents(surfaceId: "s", components: [
                comp(#"{"id":"root","component":"Text","text":"hi"}"#),
            ])),
            .createSurface(CreateSurface(surfaceId: "s", catalogId: "basic")),
        ]
        #expect(issues(messages).contains {
            $0.contains("duplicate createSurface for surface 's'")
        })
    }

    @Test("recreating a surface after deleteSurface is valid")
    func recreateAfterDelete() {
        let messages: [ServerMessage] = [
            .createSurface(CreateSurface(surfaceId: "s", catalogId: "basic")),
            .updateComponents(UpdateComponents(surfaceId: "s", components: [
                comp(#"{"id":"root","component":"Text","text":"hi"}"#),
            ])),
            .deleteSurface(DeleteSurface(surfaceId: "s")),
            .createSurface(CreateSurface(surfaceId: "s", catalogId: "basic")),
            .updateComponents(UpdateComponents(surfaceId: "s", components: [
                comp(#"{"id":"root","component":"Text","text":"again"}"#),
            ])),
        ]
        #expect(issues(messages).isEmpty)
    }

    @Test("inline createSurface components are validated like updateComponents", arguments: [
        // missing root
        #"{"id":"orphan","component":"Text","text":"no root"}"#,
        // unknown component
        #"{"id":"root","component":"Frobnicate","value":1}"#,
    ])
    func inlineComponentsValidated(componentJSON: String) {
        let messages: [ServerMessage] = [
            .createSurface(CreateSurface(
                surfaceId: "s", catalogId: "basic", components: [comp(componentJSON)])),
        ]
        #expect(!issues(messages).isEmpty)
    }
}

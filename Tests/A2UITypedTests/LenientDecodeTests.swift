import Foundation
import Testing
@testable import A2UITyped
import A2UICore
import A2UICatalog

@Suite("CatalogNode.lenientDecode")
struct LenientDecodeTests {

    private func node(_ json: String) -> CatalogNode<BasicComponent> {
        let value = try! JSONDecoder().decode(StructuredValue.self, from: Data(json.utf8))
        return CatalogNode<BasicComponent>.lenientDecode(value)
    }

    @Test func validComponentDecodesAsKnown() {
        let n = node(#"{"id":"t","component":"Text","text":"hi"}"#)
        guard case .known = n else { Issue.record("expected .known, got \(n)"); return }
        #expect(n.id == "t")
    }

    @Test func unknownNameDegradesToUnknown() {
        let n = node(#"{"id":"x","component":"FooBar"}"#)
        guard case .unknown(let name, let id, _) = n else { Issue.record("expected .unknown"); return }
        #expect(name == "FooBar")
        #expect(id == "x")
    }

    @Test func knownNameWithMalformedPropsDegradesInsteadOfVanishing() {
        // Button requires `action`; omitting it would throw in strict decode → lenient keeps a
        // visible placeholder carrying the id, rather than silently dropping the component.
        let n = node(#"{"id":"b","component":"Button","child":"c"}"#)
        guard case .unknown(let name, let id, _) = n else { Issue.record("expected .unknown, got \(n)"); return }
        #expect(name == "Button")
        #expect(id == "b")
    }

    @Test func invalidActionDegrades() {
        // The recurring LLM mistake: a non-spec action (`updateDataModel` is not `event`/`functionCall`).
        let n = node(#"{"id":"b","component":"Button","child":"c","action":{"updateDataModel":{"path":"/x"}}}"#)
        guard case .unknown(let name, _, _) = n else { Issue.record("expected .unknown, got \(n)"); return }
        #expect(name == "Button")
    }
}

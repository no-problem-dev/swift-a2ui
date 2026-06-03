import Testing
import Foundation
import A2UICore
import A2UICatalog
@testable import A2UITyped

@Suite("CatalogNode decode")
struct CatalogNodeTests {
    private func decode(_ json: String) throws -> CatalogNode<BasicComponent> {
        try JSONDecoder().decode(CatalogNode<BasicComponent>.self, from: Data(json.utf8))
    }

    @Test("known component decodes into .known")
    func known() throws {
        let node = try decode(#"{"id":"t1","component":"Text","text":"hello"}"#)
        guard case .known(let basic) = node else { Issue.record("expected .known"); return }
        #expect(basic.componentName == "Text")
        #expect(node.id == "t1")
    }

    @Test("unknown component name degrades to .unknown, preserving id + name")
    func unknown() throws {
        let node = try decode(#"{"id":"x1","component":"Sparkline","points":[1,2,3]}"#)
        guard case .unknown(let name, let id, _) = node else { Issue.record("expected .unknown"); return }
        #expect(name == "Sparkline")
        #expect(id == "x1")
    }

    @Test("basic catalog routing set covers all 18 basic components")
    func routingComplete() {
        #expect(BasicComponent.componentNames.count == 18)
        #expect(BasicComponent.componentNames.contains("Button"))
    }
}

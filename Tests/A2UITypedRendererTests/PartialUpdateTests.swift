import Testing
import Foundation
import A2UICore
import A2UICatalog
import A2UISurface
@testable import A2UITyped
@testable import A2UITypedRenderer

@MainActor
@Suite("Partial updates (updateComponents / updateDataModel)")
struct PartialUpdateTests {
    private func makeSurface() throws -> TypedSurface<BasicCatalog> {
        let json = """
        [
          {"id":"root","component":"Card","child":"col"},
          {"id":"col","component":"Column","children":["t1"]},
          {"id":"t1","component":"Text","text":{"path":"/msg"}}
        ]
        """
        let nodes = try TypedSurface<BasicCatalog>.decodeNodes(fromJSONArray: Data(json.utf8))
        let data = try JSONDecoder().decode(StructuredValue.self, from: Data(#"{"msg":"hello"}"#.utf8))
        return TypedSurface(rootId: "root", nodes: nodes, dataModel: DataModel(data))
    }

    private func text(_ surface: TypedSurface<BasicCatalog>, _ id: ComponentId) -> DynamicString? {
        guard case .known(.text(let c)) = surface.node(id) else { return nil }
        return c.text
    }

    @Test("updateDataModel re-resolves a bound Text and bumps dataVersion")
    func dataModelUpdate() throws {
        let surface = try makeSurface()
        let ctx = RenderContext(surface: surface, scope: "")
        #expect(ctx.resolve(text(surface, "t1")!) == "hello")

        let before = surface.dataVersion
        surface.applyUpdateDataModel(path: "/msg", value: .string("updated"))
        #expect(surface.dataVersion == before + 1)
        #expect(ctx.resolve(text(surface, "t1")!) == "updated")
    }

    @Test("updateComponents upserts a node by id (here: rebind Text to a literal)")
    func componentsUpsert() throws {
        let surface = try makeSurface()
        let ctx = RenderContext(surface: surface, scope: "")

        let replacement = try TypedSurface<BasicCatalog>.decodeNodes(
            fromJSONArray: Data(#"[{"id":"t1","component":"Text","text":"replaced"}]"#.utf8))
        surface.applyUpdateComponents(replacement)

        #expect(ctx.resolve(text(surface, "t1")!) == "replaced")
        // Other nodes untouched.
        #expect(surface.node("col") != nil)
    }

    @Test("updateComponents can add a brand-new node")
    func componentsAdd() throws {
        let surface = try makeSurface()
        #expect(surface.node("t2") == nil)
        let added = try TypedSurface<BasicCatalog>.decodeNodes(
            fromJSONArray: Data(#"[{"id":"t2","component":"Text","text":"new"}]"#.utf8))
        surface.applyUpdateComponents(added)
        #expect(surface.node("t2") != nil)
    }
}

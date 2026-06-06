import Testing
import Foundation
import A2UICore
import A2UICatalog
import A2UISurface
import A2UIRuntime
@testable import A2UITyped
@testable import A2UITypedRenderer

/// Template children (`{componentId, path}`) must expand in the typed renderer with per-element
/// data scopes — the regression behind "tab content renders empty" (childIds() used to drop them).
@MainActor
@Suite("Template children expansion in the typed renderer")
struct TemplateChildrenTests {
    private func makeSurface() throws -> TypedSurface<BasicCatalog> {
        let componentsJSON = """
        [
          {"id":"root","component":"Column","children":{"componentId":"item","path":"/items"}},
          {"id":"item","component":"Text","text":{"path":"name"}}
        ]
        """
        let nodes = try TypedSurface<BasicCatalog>.decodeNodes(fromJSONArray: Data(componentsJSON.utf8))
        let data = try JSONDecoder().decode(StructuredValue.self, from: Data(
            #"{"items":[{"name":"A"},{"name":"B"},{"name":"C"}]}"#.utf8))
        return TypedSurface(rootId: "root", nodes: nodes, dataModel: DataModel(data))
    }

    private func rootChildren(_ surface: TypedSurface<BasicCatalog>) throws -> ChildList {
        guard case .known(.column(let column)) = surface.node("root") else {
            throw TestError.notAColumn
        }
        return column.children
    }

    private enum TestError: Error { case notAColumn }

    @Test("template ChildList expands to one slot per array element with element scopes")
    func expandsWithScopes() throws {
        let surface = try makeSurface()
        let ctx = RenderContext(surface: surface, scope: "")
        let kids = ctx.children(try rootChildren(surface))
        #expect(kids.map(\.componentId) == ["item", "item", "item"])
        #expect(kids.map(\.basePath) == ["/items/0", "/items/1", "/items/2"])
    }

    @Test("each template instance resolves relative bindings against its element scope")
    func resolvesPerElement() throws {
        let surface = try makeSurface()
        guard case .known(.text(let text)) = surface.node("item") else {
            Issue.record("item should be Text"); return
        }
        let ctx = RenderContext(surface: surface, scope: "")
        let resolved = ctx.children(try rootChildren(surface)).map {
            RenderContext(surface: surface, scope: $0.basePath).resolve(text.text)
        }
        #expect(resolved == ["A", "B", "C"])
    }

    @Test("missing collection expands to no children (progressive rendering, not a crash)")
    func missingCollectionIsEmpty() throws {
        let surface = try makeSurface()
        surface.applyUpdateDataModel(path: "", value: .object([:]))
        let ctx = RenderContext(surface: surface, scope: "")
        #expect(ctx.children(try rootChildren(surface)).isEmpty)
    }

    @Test("data-model update re-expands the template (collection growth)")
    func reExpandsOnDataChange() throws {
        let surface = try makeSurface()
        let ctx = RenderContext(surface: surface, scope: "")
        #expect(ctx.children(try rootChildren(surface)).count == 3)
        surface.applyUpdateDataModel(path: "/items", value: .array([
            .object(["name": .string("A")]),
            .object(["name": .string("B")]),
            .object(["name": .string("C")]),
            .object(["name": .string("D")])
        ]))
        #expect(ctx.children(try rootChildren(surface)).count == 4)
    }

    @Test("static id lists keep the parent scope (unchanged behavior)")
    func staticIdsKeepScope() throws {
        let componentsJSON = """
        [
          {"id":"root","component":"Column","children":["t1"]},
          {"id":"t1","component":"Text","text":"hi"}
        ]
        """
        let nodes = try TypedSurface<BasicCatalog>.decodeNodes(fromJSONArray: Data(componentsJSON.utf8))
        let surface = TypedSurface<BasicCatalog>(rootId: "root", nodes: nodes, dataModel: DataModel())
        let ctx = RenderContext(surface: surface, scope: "/somewhere")
        let kids = ctx.children(try rootChildren(surface))
        #expect(kids == [ResolvedChild(componentId: "t1", basePath: "/somewhere")])
    }
}

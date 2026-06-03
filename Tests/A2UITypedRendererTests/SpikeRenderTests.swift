import Testing
import Foundation
import A2UICore
import A2UICatalog
import A2UISurface
@testable import A2UITyped
@testable import A2UITypedRenderer

@MainActor
@Suite("Typed renderer spike: Card > Column > Text({path})")
struct SpikeRenderTests {
    private func makeSurface() throws -> TypedSurface<BasicCatalog> {
        let componentsJSON = """
        [
          {"id":"root","component":"Card","child":"col"},
          {"id":"col","component":"Column","children":["t1"]},
          {"id":"t1","component":"Text","text":{"path":"/msg"}}
        ]
        """
        let nodes = try TypedSurface<BasicCatalog>.decodeNodes(fromJSONArray: Data(componentsJSON.utf8))
        let data = try JSONDecoder().decode(StructuredValue.self, from: Data(#"{"msg":"hello world"}"#.utf8))
        return TypedSurface(rootId: "root", nodes: nodes, dataModel: DataModel(data))
    }

    @Test("flat id-map decodes; tree is reachable by id")
    func decodesTree() throws {
        let surface = try makeSurface()
        #expect(surface.node("root") != nil)
        #expect(surface.node("col") != nil)
        guard case .known(.text) = surface.node("t1") else {
            Issue.record("t1 should be a known Text node"); return
        }
    }

    @Test("Text {path} binding resolves against the data model")
    func resolvesBinding() throws {
        let surface = try makeSurface()
        guard case .known(.text(let text)) = surface.node("t1") else {
            Issue.record("t1 should be Text"); return
        }
        let ctx = RenderContext(surface: surface, scope: "")
        #expect(ctx.resolve(text.text) == "hello world")
    }

    @Test("recursive generic surface view type-checks (zero erasure)")
    func surfaceViewCompiles() throws {
        let surface = try makeSurface()
        // Instantiating proves NodeView<BasicCatalog> ⇄ BasicCatalog.view recursion compiles
        // without AnyView. (Rendering output is validated later via snapshot parity.)
        _ = A2UISurfaceView(surface)
    }
}

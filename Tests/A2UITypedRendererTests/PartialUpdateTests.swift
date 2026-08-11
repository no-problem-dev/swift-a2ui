import StructuredDataCore
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

/// `FunctionBoundary` is the spec's permission control: `callableFrom` never travels on the wire, so
/// an agent's `callFunction` carries no proof it is allowed and the renderer has to look the name up
/// itself. It existed, was tested, and nothing on the render path called it — `TypedMessageProcessor`
/// dropped every `callFunction` with a bare `break`, so a host wiring its own dispatch got no
/// permission-checked path to use and no refusal to send back.
@MainActor
@Suite("Agent-initiated callFunction is permission-checked on the render path")
struct FunctionBoundaryWiringTests {

    private func processor() -> (TypedMessageProcessor<BasicCatalog>, Box) {
        let box = Box()
        let processor = TypedMessageProcessor<BasicCatalog>()
        processor.onRendererError = { box.errors.append($0) }
        processor.onFunctionCall = { box.calls.append($0) }
        return (processor, box)
    }

    final class Box {
        var errors: [RendererError] = []
        var calls: [CallFunctionMessage] = []
    }

    private func call(_ name: String) -> AgentMessage {
        .callFunction(CallFunctionMessage(
            functionCallId: CallId("c1"), callFunction: FunctionCall(call: name)))
    }

    @Test("a rendererOnly catalog function is refused with INVALID_FUNCTION_CALL")
    func refusesRendererOnly() {
        let (processor, box) = processor()
        // Every basic-catalog function omits `callableFrom`, which the spec reads as rendererOnly.
        processor.process(call("formatString"))
        #expect(box.calls.isEmpty)
        #expect(box.errors.count == 1)
        #expect(box.errors.first?.code == FunctionBoundary.invalidFunctionCallCode)
        #expect(box.errors.first?.functionCallId == CallId("c1"))
    }

    @Test("a name the catalog does not know is refused too")
    func refusesUnregistered() {
        let (processor, box) = processor()
        processor.process(call("definitelyNotAFunction"))
        #expect(box.calls.isEmpty)
        #expect(box.errors.first?.code == FunctionBoundary.invalidFunctionCallCode)
    }

    @Test("the refusal names whether the function exists, so a typo reads differently from a denial")
    func refusalDistinguishesTypoFromDenial() {
        let (processor, box) = processor()
        processor.process(call("formatString"))
        processor.process(call("definitelyNotAFunction"))
        #expect(box.errors[0].message.contains("rendererOnly"))
        #expect(box.errors[1].message.contains("not registered"))
    }
}

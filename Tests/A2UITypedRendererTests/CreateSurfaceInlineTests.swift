import Testing
import Foundation
import A2UICore
import A2UICatalog
import A2UISurface
@testable import A2UITyped
@testable import A2UITypedRenderer

/// v0.10: `createSurface` may carry `components` and `dataModel` inline. The official eval
/// validator treats the inline form as exactly equivalent to a following `updateComponents` /
/// root `updateDataModel`, so the processor must apply both on creation.
///
/// Shapes mirror `Spec/v0_10/test/cases/initial_state_validation.json` plus the real Gemini
/// payload that exposed the regression (inline dataModel + separate updateComponents → all
/// bindings rendered empty).
@MainActor
@Suite("createSurface inline payload (v0.10)")
struct CreateSurfaceInlineTests {

    private func decode(_ json: String) throws -> ServerMessage {
        try JSONDecoder().decode(ServerMessage.self, from: Data(json.utf8))
    }

    private func resolvedText(
        _ processor: TypedMessageProcessor<BasicCatalog>, surface: String, node: ComponentId
    ) throws -> String? {
        let surface = try #require(processor.surfaces[surface])
        guard case .known(.text(let c)) = surface.node(node) else { return nil }
        return RenderContext(surface: surface, scope: "").resolve(c.text)
    }

    @Test("spec shape: inline components + dataModel apply in one message")
    func inlineComponentsAndDataModel() throws {
        let processor = TypedMessageProcessor<BasicCatalog>()
        processor.process(try decode("""
        {"version":"v0.10","createSurface":{
          "surfaceId":"test_surface",
          "catalogId":"https://a2ui.org/specification/v0_10/catalogs/basic/catalog.json",
          "components":[
            {"id":"root","component":"Column","children":["welcome_text"]},
            {"id":"welcome_text","component":"Text","text":{"path":"/user/name"}}
          ],
          "dataModel":{"user":{"name":"John Doe"}}}}
        """))
        #expect(try resolvedText(processor, surface: "test_surface", node: "welcome_text") == "John Doe")
    }

    @Test("regression: inline dataModel + separate updateComponents (Gemini shape)")
    func inlineDataModelThenUpdateComponents() throws {
        let processor = TypedMessageProcessor<BasicCatalog>()
        processor.process([
            try decode("""
            {"version":"v0.10","createSurface":{
              "surfaceId":"calculus_problem_today",
              "catalogId":"https://a2ui.org/specification/v0_10/catalogs/basic/catalog.json",
              "dataModel":{"problem":"定積分 $I$ を求めよ。","finalAnswer":"$\\\\frac{\\\\pi}{4}$"}}}
            """),
            try decode("""
            {"version":"v0.10","updateComponents":{
              "surfaceId":"calculus_problem_today",
              "components":[
                {"id":"root","component":"Column","children":["problemText","answerText"]},
                {"id":"problemText","component":"Text","text":{"path":"/problem"}},
                {"id":"answerText","component":"Text","text":{"path":"/finalAnswer"}}
              ]}}
            """),
        ])
        #expect(try resolvedText(processor, surface: "calculus_problem_today", node: "problemText")
            == "定積分 $I$ を求めよ。")
        #expect(try resolvedText(processor, surface: "calculus_problem_today", node: "answerText")
            == #"$\frac{\pi}{4}$"#)
    }

    @Test("spec shape: inline dataModel only, components arrive later")
    func inlineDataModelOnly() throws {
        let processor = TypedMessageProcessor<BasicCatalog>()
        processor.process(try decode("""
        {"version":"v0.10","createSurface":{
          "surfaceId":"test_surface",
          "catalogId":"https://a2ui.org/specification/v0_10/catalogs/basic/catalog.json",
          "dataModel":{"themePreference":"dark"}}}
        """))
        let surface = try #require(processor.surfaces["test_surface"])
        #expect(surface.dataModel.get("/themePreference") == .string("dark"))
    }

    @Test("inline components only render without a data model")
    func inlineComponentsOnly() throws {
        let processor = TypedMessageProcessor<BasicCatalog>()
        processor.process(try decode("""
        {"version":"v0.10","createSurface":{
          "surfaceId":"test_surface",
          "catalogId":"https://a2ui.org/specification/v0_10/catalogs/basic/catalog.json",
          "components":[{"id":"root","component":"Text","text":"Minimal components configuration"}]}}
        """))
        #expect(try resolvedText(processor, surface: "test_surface", node: "root")
            == "Minimal components configuration")
    }
}

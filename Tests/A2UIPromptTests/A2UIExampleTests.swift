import Foundation
import Testing
@testable import A2UIPrompt
import A2UICore
import A2UICatalog

@Suite("A2UIExample (typed → JSON, no hand-written strings)")
struct A2UIExampleTests {

    @Test func buildsValidBlockFromTypedComponents() throws {
        let messages: [ServerMessage] = [
            .createSurface(CreateSurface(surfaceId: "s", catalogId: "basic")),
            A2UIExample.updateComponents(surfaceId: "s", [
                CardComponent(id: "root", child: "col"),
                ColumnComponent(id: "col", children: .ids(["title", "openBtn", "modal", "modalBody"])),
                TextComponent(id: "title", text: "Hi", variant: .h2),
                ButtonComponent(id: "openBtn", child: "title", action: .event(EventAction(name: "go"))),
                ModalComponent(id: "modal", trigger: "openBtn", content: "modalBody"),
                ColumnComponent(id: "modalBody", children: .ids(["title"])),
            ]),
        ]

        let blockText = A2UIExample.block(messages)
        #expect(blockText.hasPrefix("<a2ui-json>"))
        #expect(blockText.hasSuffix("</a2ui-json>"))

        // Strip the tags and decode back — proves the generated example is valid A2UI.
        let inner = blockText
            .replacingOccurrences(of: "<a2ui-json>", with: "")
            .replacingOccurrences(of: "</a2ui-json>", with: "")
        let decoded = try JSONDecoder().decode([ServerMessage].self, from: Data(inner.utf8))
        #expect(decoded.count == 2)

        // The Modal serializes with trigger/content (NOT the hand-written-string `children` bug).
        #expect(blockText.contains("\"trigger\":\"openBtn\""))
        #expect(blockText.contains("\"content\":\"modalBody\""))

        // Version is whatever the types emit — never a stale literal.
        #expect(blockText.contains("\"version\":\"\(A2UIVersion.current)\""))
    }

    @Test func referenceSurfaceIsAllValidComponents() throws {
        let messages = A2UIExample.referenceMessages(surfaceId: "main")
        #expect(messages.count == 3)

        guard case .updateComponents(let uc) = messages[1] else {
            Issue.record("expected updateComponents"); return
        }
        // Every component must decode as a real catalog node — guarantees no invalid component slips
        // into the example (the whole point of building from types).
        let data = try JSONEncoder().encode(uc.components)
        let decoded = try JSONDecoder().decode([BasicComponent].self, from: data)
        #expect(decoded.count == uc.components.count)
        #expect(decoded.contains { $0.id == "root" })

        // The rendered block round-trips back to messages.
        let block = A2UIExample.referenceSurface()
        let inner = block
            .replacingOccurrences(of: "<a2ui-json>", with: "")
            .replacingOccurrences(of: "</a2ui-json>", with: "")
        let reMessages = try JSONDecoder().decode([ServerMessage].self, from: Data(inner.utf8))
        #expect(reMessages.count == 3)
        // No JSON comments, correct version.
        #expect(!block.contains("/*"))
        #expect(block.contains("\"version\":\"\(A2UIVersion.current)\""))
    }

    @Test func componentRoundTripsThroughStructuredValue() throws {
        let sv = A2UIExample.component(TextComponent(id: "t", text: "Hello", variant: .body))
        // Re-decode the StructuredValue as a BasicComponent to confirm fidelity.
        let data = try JSONEncoder().encode(sv)
        let component = try JSONDecoder().decode(BasicComponent.self, from: data)
        #expect(component.id == "t")
        #expect(component.componentName == "Text")
    }
}

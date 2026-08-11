import Foundation
import Testing
@testable import A2UIPrompt
import A2UICore
import A2UICatalog

@Suite("A2UIExample (typed → JSON, no hand-written strings)")
struct A2UIExampleTests {

    @Test func buildsValidBlockFromTypedComponents() throws {
        let messages: [AgentMessage] = [
            .createSurface(CreateSurface(surfaceId: "s", catalogId: "basic")),
            A2UIExample.updateComponents(surfaceId: "s", [
                CardComponent(id: "root", child: "col"),
                ColumnComponent(id: "col", children: .ids(["title", "openBtn", "modal", "modalBody"])),
                TextComponent(id: "title", text: "Hi", variant: .caption),
                ButtonComponent(id: "openBtn", child: "title", action: .event(EventAction(name: "go"))),
                ModalComponent(id: "modal", trigger: "openBtn", content: "modalBody"),
                ColumnComponent(id: "modalBody", children: .ids(["title"])),
            ]),
        ]

        let blockText = A2UIExample.json(messages)
        #expect(blockText.hasPrefix("["))
        #expect(blockText.hasSuffix("]"))

        // Decode back — proves the generated example is valid A2UI.
        let decoded = try JSONDecoder().decode([AgentMessage].self, from: Data(blockText.utf8))
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

        // The rendered JSON round-trips back to messages.
        let block = A2UIExample.referenceSurface()
        let reMessages = try JSONDecoder().decode([AgentMessage].self, from: Data(block.utf8))
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

    @Test func presenterSurfaceStaysWithinItsAllowlists() throws {
        // 手本と許可セット（allowedComponents / allowedMessages に渡す集合）の同期を固定する。
        // 手本が許可外コンポーネントを使うと、pruning したカタログと教材が矛盾する。
        let messages = A2UIExample.presenterMessages(surfaceId: "main")
        #expect(messages.count == 3)

        guard case .updateComponents(let uc) = messages[1] else {
            Issue.record("expected updateComponents"); return
        }
        let data = try JSONEncoder().encode(uc.components)
        let decoded = try JSONDecoder().decode([BasicComponent].self, from: data)
        #expect(decoded.count == uc.components.count)
        for component in decoded {
            #expect(A2UIExample.presenterComponentNames.contains(component.componentName),
                    "presenter example uses disallowed component: \(component.componentName)")
        }

        let usedMessages: Set<String> = Set(messages.map {
            switch $0 {
            case .createSurface: "CreateSurfaceMessage"
            case .updateComponents: "UpdateComponentsMessage"
            case .updateDataModel: "UpdateDataModelMessage"
            case .deleteSurface: "DeleteSurfaceMessage"
            case .callFunction: "CallFunctionMessage"
            case .actionResponse: "ActionResponseMessage"
            }
        })
        #expect(usedMessages.isSubset(of: A2UIExample.presenterMessageNames))
    }

    @Test func presenterAllowlistPrunesBundledSchemas() throws {
        // presenter の許可セットで bundled スキーマを pruning した結果が
        // 「許可したものを全て含み、許可外を含まない」ことを実物で確認する。
        let builder = A2UIPromptBuilder(
            agentToRendererSchema: nil,
            commonTypesSchema: nil,
            catalogSchema: nil,
            allowedComponents: A2UIExample.presenterComponentNames,
            allowedMessages: A2UIExample.presenterMessageNames
        )
        let block = builder.schemaBlock()
        for name in A2UIExample.presenterComponentNames {
            #expect(block.contains("\"#/components/\(name)\""), "missing allowed component \(name)")
        }
        #expect(!block.contains("\"#/components/ChoicePicker\""))
        #expect(!block.contains("\"#/components/DateTimeInput\""))
        #expect(!block.contains("\"#/$defs/CallFunctionMessage\""))
        #expect(!block.contains("\"#/$defs/DeleteSurfaceMessage\""))
        #expect(block.contains("\"#/$defs/CreateSurfaceMessage\""))
    }
}

/// A package published for other people cannot decide what language its consumers ship in.
///
/// The worked example is the strongest instruction in the whole prompt — the model imitates it far
/// more literally than it follows a sentence about language. A Japanese example handed to a model
/// that was just told to write English is a contradiction inside one prompt, and the example wins.
@Suite("The worked example carries no language of its own")
struct ExampleLanguageNeutralityTests {

    /// CJK ideographs, hiragana and katakana. Latin text passes; anything here is a hard-coded
    /// natural language the host never asked for.
    private func japaneseRuns(in text: String) -> [String] {
        text.split(whereSeparator: { !isJapanese($0) }).map(String.init)
    }

    private func isJapanese(_ c: Character) -> Bool {
        c.unicodeScalars.contains { scalar in
            (0x3040...0x309F).contains(scalar.value)   // hiragana
                || (0x30A0...0x30FF).contains(scalar.value) // katakana
                || (0x4E00...0x9FFF).contains(scalar.value) // CJK unified ideographs
        }
    }

    @Test func referenceSurfaceIsNotJapanese() {
        let found = japaneseRuns(in: A2UIExample.referenceSurface())
        #expect(found.isEmpty, "reference example still contains Japanese: \(found.prefix(5))")
    }

    @Test func presenterSurfaceIsNotJapanese() {
        let found = japaneseRuns(in: A2UIExample.presenterSurface())
        #expect(found.isEmpty, "presenter example still contains Japanese: \(found.prefix(5))")
    }
}

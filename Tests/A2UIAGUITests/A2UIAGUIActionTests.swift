import StructuredDataCore
import A2UICore
import AGUICore
import Foundation
import Testing

@testable import A2UIAGUI

struct A2UIAGUIActionTests {
    private let action = UserAction(
        name: "select_recipe",
        surfaceId: "s1",
        sourceComponentId: "recipe-card-2",
        timestamp: "2026-07-30T12:00:00Z",
        context: ["recipeId": .number(StructuredNumber(unchecked: "42"))]
    )

    @Test func forwardedPropsCarriesNameAndActionName() throws {
        let props = try A2UIAGUIAction.forwardedProps(action)
        let userAction = props.objectValue?["a2uiAction"]?.objectValue?["userAction"]?.objectValue
        #expect(userAction?["name"]?.stringValue == "select_recipe")
        // renderer 実装差への防御: actionName も積む
        #expect(userAction?["actionName"]?.stringValue == "select_recipe")
        #expect(userAction?["surfaceId"]?.stringValue == "s1")
    }

    /// 繋ぎ先が `name` だけを読むなら、仕様外の `actionName` は落とせる。
    @Test func forwardedPropsCanOmitActionName() throws {
        let props = try A2UIAGUIAction.forwardedProps(action, duplicatingActionName: false)
        let userAction = props.objectValue?["a2uiAction"]?.objectValue?["userAction"]?.objectValue
        #expect(userAction?["actionName"] == nil)
        // 仕様どおりの `name` は残る
        #expect(userAction?["name"]?.stringValue == "select_recipe")
    }

    @Test func forwardedPropsMergesIntoExistingBase() throws {
        let base: StructuredValue = .object(["delishApiToken": .string("tok")])
        let props = try A2UIAGUIAction.forwardedProps(action, merging: base)
        #expect(props.objectValue?["delishApiToken"]?.stringValue == "tok")
        #expect(props.objectValue?["a2uiAction"] != nil)
    }

    @Test func serverSideExtractionRoundTrips() throws {
        let props = try A2UIAGUIAction.forwardedProps(action)
        let extracted = try A2UIAGUIAction.userAction(in: props)
        #expect(extracted == action)
    }

    @Test func extractionReturnsNilWhenAbsent() throws {
        #expect(try A2UIAGUIAction.userAction(in: .object(["other": .bool(true)])) == nil)
    }

    @Test func syntheticMessagePairShape() throws {
        let messages = try A2UIAGUIAction.syntheticMessages(
            for: action,
            assistantMessageId: "am1",
            toolCallId: "tc1",
            toolMessageId: "tm1"
        )
        #expect(messages.count == 2)
        guard case .assistant(let assistant) = messages[0], case .tool(let tool) = messages[1] else {
            Issue.record("expected assistant + tool pair")
            return
        }
        #expect(assistant.content == "")
        #expect(assistant.toolCalls?.first?.function.name == "log_a2ui_event")
        #expect(assistant.toolCalls?.first?.id == "tc1")
        #expect(tool.toolCallId == "tc1")
        // 人間可読の 1 行(公式ミドルウェアの形)
        #expect(tool.content.hasPrefix(#"User performed action "select_recipe" on surface "s1" (component: recipe-card-2). Context: "#))
        #expect(tool.content.contains(#""recipeId":42"#))
        // tool call 引数は userAction の JSON
        #expect(assistant.toolCalls?.first?.function.arguments.contains(#""name":"select_recipe""#) == true)
    }
}

struct A2UISchemaContextTests {
    @Test func declarationUsesExactDescriptionConstant() throws {
        let entry = try A2UISchemaContext.declaration(catalogId: "delish", components: .array([]))
        // em dash(U+2014)を含むバイト一致の wire contract
        #expect(entry.description == "A2UI Component Schema \u{2014} available components for generating UI surfaces. Use these component names and properties when creating A2UI operations.")
        #expect(entry.value.contains(#""catalogId":"delish""#))
    }

    @Test func serverSideCatalogIdExtraction() throws {
        let entry = try A2UISchemaContext.declaration(catalogId: "delish", components: .array([]))
        let context = [AGUIContext(description: "unrelated", value: "x"), entry]
        #expect(A2UISchemaContext.declaredCatalogId(in: context) == "delish")
        #expect(A2UISchemaContext.declaredCatalogId(in: [AGUIContext(description: "unrelated", value: "x")]) == nil)
    }

    @Test func renderToolExcludesCatalogId() {
        let tool = A2UIRenderTool.definition()
        #expect(tool.name == "render_a2ui")
        let properties = tool.parameters.objectValue?["properties"]?.objectValue
        #expect(properties?["surfaceId"] != nil)
        #expect(properties?["components"] != nil)
        #expect(properties?["data"] != nil)
        // カタログ選択はホストの権限 — 引数に catalogId を含めない
        #expect(properties?["catalogId"] == nil)
        let required = tool.parameters.objectValue?["required"]?.arrayValue?.compactMap(\.stringValue)
        #expect(required == ["surfaceId", "components"])
    }
}

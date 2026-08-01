import Foundation
import Testing
@testable import A2UICore
@testable import A2UIParser

private let createSurfaceJSON = """
{"version":"v1.0","createSurface":{"surfaceId":"s1","catalogId":"basic"}}
"""

@Suite("A2UITextSalvage — テキストに混入した A2UI JSON の救済")
struct A2UITextSalvageTests {

    @Test("```json フェンスの A2UI を抽出しテキストから除去")
    func salvagesFencedJSON() {
        let text = """
        レシピを表示します。

        ```json
        [\(createSurfaceJSON)]
        ```
        """
        let result = A2UITextSalvage.salvage(text)
        #expect(result.messages == [.createSurface(CreateSurface(surfaceId: "s1", catalogId: "basic"))])
        #expect(result.text == "レシピを表示します。")
    }

    @Test("言語タグなしフェンスも対象")
    func salvagesFenceWithoutLanguage() {
        let text = """
        こちらです。
        ```
        [\(createSurfaceJSON)]
        ```
        """
        let result = A2UITextSalvage.salvage(text)
        #expect(result.messages.count == 1)
        #expect(result.text == "こちらです。")
    }

    @Test("<a2ui-json> タグも対象")
    func salvagesTaggedJSON() {
        let text = "どうぞ。<a2ui-json>[\(createSurfaceJSON)]</a2ui-json>あとがき"
        let result = A2UITextSalvage.salvage(text)
        #expect(result.messages.count == 1)
        #expect(result.text.contains("どうぞ。"))
        #expect(result.text.contains("あとがき"))
        #expect(!result.text.contains("createSurface"))
    }

    @Test("裸のトップレベル JSON 配列も対象")
    func salvagesBareArray() {
        let text = "表示します。\n[\(createSurfaceJSON)]"
        let result = A2UITextSalvage.salvage(text)
        #expect(result.messages.count == 1)
        #expect(result.text == "表示します。")
    }

    @Test("複数ブロックを出現順に抽出")
    func salvagesMultipleBlocks() {
        let second = """
        {"version":"v1.0","createSurface":{"surfaceId":"s2","catalogId":"basic"}}
        """
        let text = """
        ひとつ目。
        ```json
        [\(createSurfaceJSON)]
        ```
        ふたつ目。
        ```json
        [\(second)]
        ```
        """
        let result = A2UITextSalvage.salvage(text)
        #expect(result.messages.count == 2)
        guard case .createSurface(let first) = result.messages[0],
              case .createSurface(let last) = result.messages[1] else {
            Issue.record("expected two createSurface")
            return
        }
        #expect(first.surfaceId == "s1")
        #expect(last.surfaceId == "s2")
    }

    @Test("A2UI でない JSON はテキストに残す")
    func keepsNonA2UIJSON() {
        let text = """
        検索結果はこちらです。
        ```json
        [{"recipeId":"123","title":"唐揚げ"}]
        ```
        """
        let result = A2UITextSalvage.salvage(text)
        #expect(result.messages.isEmpty)
        // 誤ってサーフェス化せず、テキストとして保持する
        #expect(result.text.contains("recipeId"))
    }

    @Test("A2UI が無ければテキストはそのまま")
    func passesThroughPlainText() {
        let result = A2UITextSalvage.salvage("こんにちは！何かお手伝いできることはありますか？")
        #expect(result.messages.isEmpty)
        #expect(result.text == "こんにちは！何かお手伝いできることはありますか？")
        #expect(result.isEmpty)
    }

    @Test("文字列リテラル内の括弧で誤検出しない")
    func handlesBracketsInsideStrings() {
        let payload = #"[{"version":"v1.0","updateDataModel":{"surfaceId":"s1","path":"/","value":{"note":"配列は [1, 2] のように書く"}}}]"#
        let result = A2UITextSalvage.salvage("説明します。\n\(payload)")
        #expect(result.messages.count == 1)
        #expect(result.text == "説明します。")
    }

    @Test("閉じフェンスがない不完全な出力は壊さない")
    func toleratesUnterminatedFence() {
        let text = """
        途中で切れました。
        ```json
        [\(createSurfaceJSON)
        """
        let result = A2UITextSalvage.salvage(text)
        // 抽出できなくても例外にならず、テキストは保持される
        #expect(result.messages.isEmpty)
        #expect(result.text.contains("途中で切れました。"))
    }
}

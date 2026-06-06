import Testing
import A2UITyped
@testable import A2UITypedRenderer

/// TextComponent のテキストが MarkdownView 経路に乗るかの判定テスト。
///
/// LLM が数式（LaTeX）を出力した場合、他の Markdown 記法を含まなくても
/// MarkdownView（数式パース対応）へルーティングされる必要がある。
struct MarkdownDetectionTests {

    @Test("数式デリミタを含むテキストは Markdown 経路に乗る", arguments: [
        "$$E = mc^2$$",
        #"結論: \(a \neq 0\) が条件です"#,
        #"\[x = \frac{-b \pm \sqrt{b^2-4ac}}{2a}\]"#,
        "value $x$ here",
        "二次方程式 $ax^2 + bx + c = 0$ を解く",
    ])
    func mathRoutesToMarkdown(text: String) {
        #expect(BasicCatalog.containsMarkdownFormatting(text))
    }

    @Test("数式を含まない平文は plain Text のまま", arguments: [
        "plain text without any formatting",
        "costs $5 and $10 total",
        "$ 100 の予算",
        "終わりにドルがある $",
    ])
    func nonMathStaysPlain(text: String) {
        #expect(!BasicCatalog.containsMarkdownFormatting(text))
    }

    @Test("既存の Markdown 記法検出は維持される", arguments: [
        "**bold** text",
        "# Heading",
        "- list item",
        "`code`",
    ])
    func existingMarkdownStillDetected(text: String) {
        #expect(BasicCatalog.containsMarkdownFormatting(text))
    }

    // heading/caption variant は MarkdownView に乗らないため、数式は
    // containsMathDelimiters の判定で MathText 経路に入る（A2A デモの
    // 答えカード `$$-6$$` が h3 のまま生表示された回帰の防止）。

    @Test("heading variant の数式は MathText 経路に乗る", arguments: [
        "$$-6$$",
        "答え: $x = 3$",
        #"条件: \(a \neq 0\)"#,
    ])
    func headingMathRoutesToMathText(text: String) {
        #expect(BasicCatalog.containsMathDelimiters(text))
    }

    @Test("通貨表記の heading は MathText 経路に乗らない", arguments: [
        "costs $5 and $10 total",
        "$ 100 の予算",
    ])
    func headingCurrencyStaysPlain(text: String) {
        #expect(!BasicCatalog.containsMathDelimiters(text))
    }
}

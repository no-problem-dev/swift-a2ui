import Testing
@testable import A2UIPrompt

@Suite("A2UIExampleFormatter (port of catalog.load_examples formatting)")
struct A2UIExampleFormatterTests {

    @Test("単一 example をマーカーで包む")
    func formatsSingleExample() {
        let formatted = A2UIExampleFormatter.format(name: "chart", content: "[{}]")
        #expect(formatted == "---BEGIN chart---\n[{}]\n---END chart---")
    }

    @Test("複数 example を空行で結合")
    func mergesExamples() {
        let merged = A2UIExampleFormatter.merge([
            (name: "chart", content: "[1]"),
            (name: "map", content: "[2]"),
        ])
        #expect(merged == "---BEGIN chart---\n[1]\n---END chart---\n\n---BEGIN map---\n[2]\n---END map---")
    }

    @Test("空リストは空文字列")
    func emptyListYieldsEmptyString() {
        #expect(A2UIExampleFormatter.merge([]) == "")
    }
}

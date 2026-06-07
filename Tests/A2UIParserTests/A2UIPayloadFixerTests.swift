import Foundation
import Testing
@testable import A2UIParser
@testable import A2UICore

private let createSurfaceJSON = """
{"version":"v0.10","createSurface":{"surfaceId":"s1","catalogId":"basic"}}
"""

@Suite("A2UIPayloadFixer (port of payload_fixer.py)")
struct A2UIPayloadFixerTests {

    @Test("有効な配列はそのまま decode")
    func parsesValidArray() throws {
        let messages = try A2UIPayloadFixer.parseAndFix("[\(createSurfaceJSON)]")
        #expect(messages == [.createSurface(CreateSurface(surfaceId: "s1", catalogId: "basic"))])
    }

    @Test("単一オブジェクトは配列に wrap")
    func wrapsSingleObject() throws {
        let messages = try A2UIPayloadFixer.parseAndFix(createSurfaceJSON)
        #expect(messages.count == 1)
    }

    @Test("スマートクォートを正規化して decode")
    func normalizesSmartQuotes() throws {
        let smart = "[\(createSurfaceJSON)]"
            .replacingOccurrences(of: "\"surfaceId\"", with: "\u{201C}surfaceId\u{201D}")
        let messages = try A2UIPayloadFixer.parseAndFix(smart)
        #expect(messages.count == 1)
    }

    @Test("trailing comma を除去して decode")
    func removesTrailingCommas() throws {
        let trailing = """
        [{"version":"v0.10","createSurface":{"surfaceId":"s1","catalogId":"basic",},},]
        """
        let messages = try A2UIPayloadFixer.parseAndFix(trailing)
        #expect(messages.count == 1)
    }

    @Test("修復不能な JSON は Failed to parse JSON で throw")
    func throwsOnUnfixableJSON() {
        #expect(throws: A2UIPayloadFixer.ParseError.self) {
            try A2UIPayloadFixer.parseAndFix("not json at all {{{")
        }
        do {
            _ = try A2UIPayloadFixer.parseAndFix("not json at all {{{")
            Issue.record("expected throw")
        } catch let error as A2UIPayloadFixer.ParseError {
            #expect(error.description.hasPrefix("Failed to parse JSON"))
        } catch {
            Issue.record("unexpected error type: \(error)")
        }
    }

    @Test("空文字列は throw")
    func throwsOnEmpty() {
        #expect(throws: A2UIPayloadFixer.ParseError.self) {
            try A2UIPayloadFixer.parseAndFix("")
        }
    }

    @Test("LaTeX のエスケープ不足バックスラッシュを修復してパース")
    func repairsUnderEscapedLatex() throws {
        // \int / \infty の "\i" は不正な JSON エスケープ — 修復後にパースできること
        let payload = #"[{"version":"v0.10","updateDataModel":{"surfaceId":"s1","path":"/","value":{"problem":"$\int_{0}^{\infty} e^{-x^2} dx$"}}}]"#
        let messages = try A2UIPayloadFixer.parseAndFix(payload)
        #expect(messages.count == 1)
        guard case .updateDataModel(let udm) = messages[0] else {
            Issue.record("expected updateDataModel")
            return
        }
        #expect(udm.value?["problem"].stringValue == #"$\int_{0}^{\infty} e^{-x^2} dx$"#)
    }

    @Test("正しいエスケープは修復で壊さない")
    func preservesValidEscapes() throws {
        // \\theta（正しくエスケープ済み）と \infty（不足）の混在 — 公式 flash 系の実出力パターン
        let payload = #"[{"version":"v0.10","updateDataModel":{"surfaceId":"s1","path":"/","value":{"a":"$\\theta$","b":"$\infty$"}}}]"#
        let messages = try A2UIPayloadFixer.parseAndFix(payload)
        guard case .updateDataModel(let udm) = messages[0] else {
            Issue.record("expected updateDataModel")
            return
        }
        #expect(udm.value?["a"].stringValue == #"$\theta$"#)
        #expect(udm.value?["b"].stringValue == #"$\infty$"#)
    }
}

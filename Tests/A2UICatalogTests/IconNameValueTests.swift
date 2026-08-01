import A2UICore
import Foundation
import Testing

@testable import A2UICatalog

/// `Icon.name` の 3 分岐（公式 v1.0 catalog の `oneOf`）:
/// プリセット名 / `{svgPath: DynamicString}` / `{path: …}` データバインディング。
@Suite("IconNameValue (v1.0 Icon.name oneOf)")
struct IconNameValueTests {

    private func decode(_ json: String) throws -> IconNameValue {
        try JSONDecoder().decode(IconNameValue.self, from: Data(json.utf8))
    }
    private func encoded(_ value: IconNameValue) throws -> String {
        String(decoding: try JSONEncoder().encode(value), as: UTF8.self)
    }

    @Test("a preset name decodes to .preset")
    func presetName() throws {
        #expect(try decode(#""search""#) == .preset(.search))
    }

    @Test("an unrecognised name is kept verbatim so it can round-trip")
    func unknownNameIsKept() throws {
        #expect(try decode(#""notAPresetIcon""#) == .raw("notAPresetIcon"))
        #expect(try encoded(.raw("notAPresetIcon")) == #""notAPresetIcon""#)
    }

    @Test("a data binding decodes to .binding")
    func binding() throws {
        #expect(try decode(#"{"path":"/playIcon"}"#) == .binding(DataBinding(path: "/playIcon")))
    }

    /// v1.0 keeps the custom-SVG branch (as a DynamicString, so it may itself be bound).
    @Test("svgPath decodes and round-trips")
    func svgPath() throws {
        let literal = try decode(#"{"svgPath":"M0 0 L10 10"}"#)
        #expect(literal == .svgPath(.literal("M0 0 L10 10")))
        #expect(try encoded(literal) == #"{"svgPath":"M0 0 L10 10"}"#)

        let bound = try decode(#"{"svgPath":{"path":"/icon/svg"}}"#)
        #expect(bound == .svgPath(.binding(DataBinding(path: "/icon/svg"))))
    }

    @Test("an object with neither svgPath nor path is rejected")
    func rejectsUnknownObject() {
        #expect(throws: (any Error).self) { try decode(#"{"nope":1}"#) }
    }
}

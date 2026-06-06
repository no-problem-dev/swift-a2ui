import Foundation
import Testing
@testable import A2UIParser
@testable import A2UICore

// MARK: - Helpers

private let createSurfaceJSON = """
{"version":"v0.10","createSurface":{"surfaceId":"s1","catalogId":"basic"}}
"""

private let deleteSurfaceJSON = """
{"version":"v0.10","deleteSurface":{"surfaceId":"s1"}}
"""

private let updateDataModelJSON = """
{"version":"v0.10","updateDataModel":{"surfaceId":"s1","path":"/name","value":"Alice"}}
"""

private let createSurfaceArrayJSON = """
[\(createSurfaceJSON)]
"""

private let twoMessagesArrayJSON = """
[\(createSurfaceJSON),\(deleteSurfaceJSON)]
"""

private let expectedCreateSurface = ServerMessage.createSurface(
    CreateSurface(surfaceId: "s1", catalogId: "basic")
)
private let expectedDeleteSurface = ServerMessage.deleteSurface(
    DeleteSurface(surfaceId: "s1")
)

// MARK: - BlockParserTests

@Suite("A2UIBlockParser")
struct BlockParserTests {

    @Test func parsesSingleBlock() {
        let input = """
        Here's a booking form:
        <a2ui-json>
        \(createSurfaceArrayJSON)
        </a2ui-json>
        And here's some more text.
        """
        let parts = A2UIBlockParser.parse(input)
        #expect(parts.count == 3)
        #expect(parts[0] == .text("Here's a booking form:"))
        #expect(parts[1] == .messages([expectedCreateSurface]))
        #expect(parts[2] == .text("And here's some more text."))
    }

    @Test func parsesMultipleBlocks() {
        let input = """
        First:
        <a2ui-json>\(createSurfaceArrayJSON)</a2ui-json>
        Second:
        <a2ui-json>[\(deleteSurfaceJSON)]</a2ui-json>
        Done.
        """
        let parts = A2UIBlockParser.parse(input)
        #expect(parts.count == 5)
        #expect(parts[0] == .text("First:"))
        #expect(parts[1] == .messages([expectedCreateSurface]))
        #expect(parts[2] == .text("Second:"))
        #expect(parts[3] == .messages([expectedDeleteSurface]))
        #expect(parts[4] == .text("Done."))
    }

    @Test func parsesTextOnly() {
        let input = "No tags here, just plain text."
        let parts = A2UIBlockParser.parse(input)
        #expect(parts.count == 1)
        #expect(parts[0] == .text("No tags here, just plain text."))
    }

    @Test func parsesEmptyInput() {
        let parts = A2UIBlockParser.parse("")
        #expect(parts.isEmpty)
    }

    @Test func handlesMarkdownCodeFence() {
        let fencedJSON = """
        ```json
        \(createSurfaceArrayJSON)
        ```
        """
        let input = "<a2ui-json>\(fencedJSON)</a2ui-json>"
        let parts = A2UIBlockParser.parse(input)
        #expect(parts.count == 1)
        #expect(parts[0] == .messages([expectedCreateSurface]))
    }

    @Test func handlesEmptyBlock() {
        // An empty block should produce no parts (decode fails silently)
        let input = "Before<a2ui-json></a2ui-json>After"
        let parts = A2UIBlockParser.parse(input)
        // Empty block decodes to nothing; text parts are trimmed
        #expect(parts.contains(.text("Before")))
        #expect(parts.contains(.text("After")))
        #expect(!parts.contains(where: { $0.messages != nil }))
    }

    @Test func handlesUnclosedTag() {
        // Text before the unclosed tag is emitted; remaining buffer becomes text
        let input = "Before<a2ui-json>some incomplete json"
        let parts = A2UIBlockParser.parse(input)
        #expect(parts.count == 2)
        #expect(parts[0] == .text("Before"))
        #expect(parts[1] == .text("some incomplete json"))
    }

    @Test func parsesSingleMessage() {
        // A single object (not wrapped in array) should also decode
        let input = "<a2ui-json>\(createSurfaceJSON)</a2ui-json>"
        let parts = A2UIBlockParser.parse(input)
        #expect(parts.count == 1)
        #expect(parts[0] == .messages([expectedCreateSurface]))
    }

    @Test func parsesMessageArray() {
        // Two messages in one block
        let input = "<a2ui-json>\(twoMessagesArrayJSON)</a2ui-json>"
        let parts = A2UIBlockParser.parse(input)
        #expect(parts.count == 1)
        #expect(parts[0] == .messages([expectedCreateSurface, expectedDeleteSurface]))
    }

    @Test func parsesBlockWithNoSurroundingText() {
        let input = "<a2ui-json>\(createSurfaceArrayJSON)</a2ui-json>"
        let parts = A2UIBlockParser.parse(input)
        #expect(parts.count == 1)
        #expect(parts[0] == .messages([expectedCreateSurface]))
    }

    @Test func ignoresInvalidJSON() {
        let input = "<a2ui-json>{ not valid json }</a2ui-json>After"
        let parts = A2UIBlockParser.parse(input)
        // Invalid JSON block is silently dropped; trailing text is kept
        #expect(parts.count == 1)
        #expect(parts[0] == .text("After"))
    }
}

// MARK: - StreamingParserTests

@Suite("A2UIStreamingParser")
struct StreamingParserTests {

    @Test func feedsChunksAndExtractsComplete() {
        let parser = A2UIStreamingParser()

        // First chunk: text and opening tag
        var parts = parser.feed("Hello <a2ui-json>")
        #expect(parts.isEmpty) // No complete block yet

        // Second chunk: JSON content and closing tag
        parts = parser.feed("\(createSurfaceArrayJSON)</a2ui-json> World")
        #expect(parts.count == 2)
        #expect(parts[0] == .text("Hello"))
        #expect(parts[1] == .messages([expectedCreateSurface]))

        // Finalize flushes remaining text
        let final = parser.finalize()
        #expect(final.count == 1)
        #expect(final[0] == .text("World"))
    }

    @Test func feedsSingleChunkWithCompleteBlock() {
        let parser = A2UIStreamingParser()
        let parts = parser.feed("Intro <a2ui-json>\(createSurfaceArrayJSON)</a2ui-json> Outro")
        #expect(parts.count == 2)
        #expect(parts[0] == .text("Intro"))
        #expect(parts[1] == .messages([expectedCreateSurface]))

        let final = parser.finalize()
        #expect(final.count == 1)
        #expect(final[0] == .text("Outro"))
    }

    @Test func feedsMultipleBlocksInOneChunk() {
        let parser = A2UIStreamingParser()
        let input = "A<a2ui-json>[\(createSurfaceJSON)]</a2ui-json>B<a2ui-json>[\(deleteSurfaceJSON)]</a2ui-json>C"
        let parts = parser.feed(input)
        #expect(parts.count == 4)
        #expect(parts[0] == .text("A"))
        #expect(parts[1] == .messages([expectedCreateSurface]))
        #expect(parts[2] == .text("B"))
        #expect(parts[3] == .messages([expectedDeleteSurface]))

        let final = parser.finalize()
        #expect(final.count == 1)
        #expect(final[0] == .text("C"))
    }

    @Test func finalizesRemainingText() {
        let parser = A2UIStreamingParser()
        _ = parser.feed("Some text with no tags")
        let final = parser.finalize()
        #expect(final.count == 1)
        #expect(final[0] == .text("Some text with no tags"))
    }

    @Test func finalizesEmptyBuffer() {
        let parser = A2UIStreamingParser()
        let final = parser.finalize()
        #expect(final.isEmpty)
    }

    @Test func resetClearsBuffer() {
        let parser = A2UIStreamingParser()
        _ = parser.feed("accumulated text")
        parser.reset()
        let final = parser.finalize()
        #expect(final.isEmpty)
    }

    @Test func handlesChunkedJSON() {
        // JSON split across multiple feed calls
        let parser = A2UIStreamingParser()
        var parts = parser.feed("<a2ui-json>{\"version\":\"v0.10\",")
        #expect(parts.isEmpty)
        parts = parser.feed("\"createSurface\":{\"surfaceId\":\"s1\",")
        #expect(parts.isEmpty)
        parts = parser.feed("\"catalogId\":\"basic\"}}</a2ui-json>")
        #expect(parts.count == 1)
        #expect(parts[0] == .messages([expectedCreateSurface]))
    }
}

// MARK: - JSONSanitizerTests

@Suite("JSONSanitizer")
struct JSONSanitizerTests {

    @Test func removesJsonCodeFence() {
        let input = "```json\n[1,2,3]\n```"
        let result = JSONSanitizer.sanitize(input)
        #expect(result == "[1,2,3]")
    }

    @Test func removesPlainCodeFence() {
        let input = "```\n[1,2,3]\n```"
        let result = JSONSanitizer.sanitize(input)
        #expect(result == "[1,2,3]")
    }

    @Test func removesTrailingCommaBeforeBrace() {
        let input = #"{"a":1,"b":2,}"#
        let result = JSONSanitizer.sanitize(input)
        #expect(result == #"{"a":1,"b":2}"#)
    }

    @Test func removesTrailingCommaBeforeBracket() {
        let input = "[1,2,3,]"
        let result = JSONSanitizer.sanitize(input)
        #expect(result == "[1,2,3]")
    }

    @Test func removesTrailingCommaWithWhitespace() {
        let input = "[1, 2, 3, \n]"
        let result = JSONSanitizer.sanitize(input)
        #expect(result == "[1, 2, 3]")
    }

    @Test func stripsLeadingAndTrailingWhitespace() {
        let input = "  [1,2]  "
        let result = JSONSanitizer.sanitize(input)
        #expect(result == "[1,2]")
    }

    @Test func passesCleanJSONUnchanged() {
        let input = #"{"version":"v0.10","createSurface":{"surfaceId":"s1","catalogId":"basic"}}"#
        let result = JSONSanitizer.sanitize(input)
        #expect(result == input)
    }

    @Test func handlesOnlyFenceLine() {
        let input = "```"
        let result = JSONSanitizer.sanitize(input)
        #expect(result == "")
    }

    @Test func removesCodeFenceAndSanitizesTrailingComma() {
        let input = "```json\n{\"a\":1,}\n```"
        let result = JSONSanitizer.sanitize(input)
        #expect(result == #"{"a":1}"#)
    }

    // MARK: - Comment stripping (LLMs frequently emit `//` and `/* */` in a2ui-json blocks)

    @Test func stripsBlockComment() {
        let result = JSONSanitizer.stripComments(#"{"a":1 /* note */, "b":2}"#)
        #expect(!result.contains("/* note */"))
        #expect(result.contains("\"a\":1"))
        #expect(result.contains("\"b\":2"))
    }

    @Test func stripsLineComment() {
        let result = JSONSanitizer.stripComments("{\n  \"a\": 1 // hi\n}")
        #expect(!result.contains("// hi"))
        #expect(result.contains("\"a\": 1"))
    }

    @Test func preservesSlashesInsideStrings() {
        // `//` inside a string (e.g. a URL) must NOT be treated as a comment.
        let result = JSONSanitizer.stripComments(#"{"url":"https://example.com/a//b"}"#)
        #expect(result.contains("https://example.com/a//b"))
    }

    @Test func resilientDecodeKeepsValidMessagesWhenOneIsBad() {
        // Middle message has an unsupported version → must be skipped, NOT discard the whole surface.
        let input = """
        <a2ui-json>
        [
          { "version": "v0.10", "createSurface": { "surfaceId": "s1", "catalogId": "basic" } },
          { "version": "v0.8",  "createSurface": { "surfaceId": "bad", "catalogId": "basic" } },
          { "version": "v0.10", "updateDataModel": { "surfaceId": "s1", "value": { "k": "v" } } }
        ]
        </a2ui-json>
        """
        let parts = A2UIBlockParser.parse(input)
        #expect(parts.first?.messages?.count == 2)  // the two v0.10 messages survive
    }

    @Test func commentedBlockParsesIntoMessages() {
        let input = """
        <a2ui-json>
        [
          /* --- surface --- */
          { "version": "v0.10", "createSurface": { "surfaceId": "s1", "catalogId": "basic" } }, // line comment
          { "version": "v0.10", "updateDataModel": { "surfaceId": "s1", "value": { "url": "https://example.com/a//b" } } }
        ]
        </a2ui-json>
        """
        let parts = A2UIBlockParser.parse(input)
        #expect(parts.count == 1)
        #expect(parts.first?.messages?.count == 2)
    }
}

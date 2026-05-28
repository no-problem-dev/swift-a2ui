import A2UICore
import Foundation
import Testing
@testable import A2UIPromptCompact

@Suite("CommonTypesCompactor")
struct CommonTypesCompactorTests {

    @Test("removes FunctionCall and DynamicValue from $defs")
    func removesFunctionCallDefs() throws {
        let input = """
        {
            "$defs": {
                "FunctionCall": {"type": "object"},
                "DynamicValue": {"type": "object"},
                "DynamicString": {"oneOf": [{"type": "string"}]},
                "Other": {"type": "string"}
            }
        }
        """
        let compact = CommonTypesCompactor.compact(input)
        let value = try JSONDecoder().decode(AnyCodable.self, from: Data(compact.utf8))
        guard case .object(let root) = value,
              case .object(let defs)? = root["$defs"] else {
            Issue.record("unexpected shape")
            return
        }
        #expect(defs["FunctionCall"] == nil)
        #expect(defs["DynamicValue"] == nil)
        #expect(defs["DynamicString"] != nil)
        #expect(defs["Other"] != nil)
    }

    @Test("strips FunctionCall oneOf branch from Dynamic types")
    func stripsFunctionCallBranch() throws {
        let input = """
        {
            "$defs": {
                "DynamicString": {
                    "oneOf": [
                        {"type": "string"},
                        {"allOf": [{"$ref": "#/$defs/FunctionCall"}]}
                    ]
                },
                "FunctionCall": {"type": "object"}
            }
        }
        """
        let compact = CommonTypesCompactor.compact(input)
        let value = try JSONDecoder().decode(AnyCodable.self, from: Data(compact.utf8))
        guard case .object(let root) = value,
              case .object(let defs)? = root["$defs"],
              case .object(let dynStr)? = defs["DynamicString"],
              case .array(let oneOf)? = dynStr["oneOf"] else {
            Issue.record("unexpected shape")
            return
        }
        #expect(oneOf.count == 1)
        // 残ったのは {"type": "string"}
        guard case .object(let only) = oneOf[0],
              case .string(let t)? = only["type"] else {
            Issue.record("expected primitive string branch")
            return
        }
        #expect(t == "string")
    }

    @Test("strips URL-style FunctionCall $ref as well")
    func stripsURLStyleRef() throws {
        let input = """
        {
            "$defs": {
                "DynamicNumber": {
                    "oneOf": [
                        {"type": "number"},
                        {"allOf": [{"$ref": "https://example.com/common_types.json#/$defs/FunctionCall"}]}
                    ]
                }
            }
        }
        """
        let compact = CommonTypesCompactor.compact(input)
        let value = try JSONDecoder().decode(AnyCodable.self, from: Data(compact.utf8))
        guard case .object(let root) = value,
              case .object(let defs)? = root["$defs"],
              case .object(let dynNum)? = defs["DynamicNumber"],
              case .array(let oneOf)? = dynNum["oneOf"] else {
            Issue.record("unexpected shape")
            return
        }
        #expect(oneOf.count == 1)
    }

    @Test("returns input unchanged when JSON is invalid")
    func passthroughOnInvalidJSON() {
        let bad = "not json at all"
        #expect(CommonTypesCompactor.compact(bad) == bad)
    }
}

@Suite("A2UIPromptCompactBuilder")
struct A2UIPromptCompactBuilderTests {

    @Test("schemaBlock contains compacted common_types without FunctionCall")
    func schemaBlockHasNoFunctionCall() throws {
        let builder = A2UIPromptCompactBuilder()
        let block = builder.schemaBlock()
        #expect(block.contains("DynamicString"))      // 通常型は残る
        #expect(!block.contains("\"FunctionCall\""))  // 型名としては消えている
    }

    @Test("buildSystemPrompt embeds schema block by default")
    func systemPromptIncludesSchema() {
        let builder = A2UIPromptCompactBuilder()
        let prompt = builder.buildSystemPrompt(role: "test role")
        #expect(prompt.contains("test role"))
        #expect(prompt.contains("Server To Client Schema"))
    }
}

import Foundation
import Testing
import A2UICore
import JSONParsing

@testable import A2UIPrompt

/// 公式 conformance スイート（`agent_sdks/conformance/suites/catalog.yaml`）の
/// prune / render ケースの逐語移植。入力・期待値は YAML の値そのまま。
/// これが通る限り、pruning の挙動は公式 Python SDK と一致する。
@Suite("Official pruning conformance (catalog.yaml)")
struct OfficialPruningConformanceTests {

    private func parse(_ json: String) -> StructuredValue {
        try! JSONParser().parse(json)
    }

    private func prune(
        catalog: String = ##"{"catalogId":"basic"}"##,
        s2c: String = "{}",
        common: String = "{}",
        allowedComponents: Set<String>? = nil,
        allowedMessages: Set<String>? = nil
    ) -> (catalog: StructuredValue, serverToClient: StructuredValue, commonTypes: StructuredValue) {
        SchemaPruner.withPruning(
            catalog: parse(catalog),
            serverToClient: parse(s2c),
            commonTypes: parse(common),
            allowedComponents: allowedComponents,
            allowedMessages: allowedMessages
        )
    }

    @Test("test_with_pruning_components")
    func pruningComponents() {
        let result = prune(
            catalog: ##"{"catalogId":"basic","components":{"Text":{"type":"object"},"Button":{"type":"object"},"Image":{"type":"object"}}}"##,
            allowedComponents: ["Text", "Button"]
        )
        #expect(result.catalog == parse(
            ##"{"catalogId":"basic","components":{"Text":{"type":"object"},"Button":{"type":"object"}}}"##
        ))
    }

    @Test("test_with_pruning_components_v09 (anyComponent oneOf)")
    func pruningComponentsAnyComponent() {
        let result = prune(
            catalog: """
            {"catalogId":"basic",
             "$defs":{"anyComponent":{"oneOf":[
                {"$ref":"#/components/Text"},
                {"$ref":"#/components/Button"},
                {"$ref":"#/components/Image"}]}},
             "components":{"Text":{},"Button":{},"Image":{}}}
            """,
            allowedComponents: ["Text"]
        )
        #expect(result.catalog == parse(
            ##"{"catalogId":"basic","$defs":{"anyComponent":{"oneOf":[{"$ref":"#/components/Text"}]}},"components":{"Text":{}}}"##
        ))
    }

    @Test("test_with_pruning_messages (v0.9 oneOf + $defs)")
    func pruningMessages() {
        let result = prune(
            s2c: """
            {"oneOf":[
                {"$ref":"#/$defs/MessageA"},
                {"$ref":"#/$defs/MessageB"},
                {"$ref":"#/$defs/MessageC"}],
             "$defs":{
                "MessageA":{"type":"object","properties":{"a":{"type":"string"}}},
                "MessageB":{"type":"object","properties":{"b":{"type":"string"}}},
                "MessageC":{"type":"object","properties":{"c":{"type":"string"}}}}}
            """,
            allowedMessages: ["MessageA", "MessageC"]
        )
        #expect(result.serverToClient == parse("""
            {"oneOf":[
                {"$ref":"#/$defs/MessageA"},
                {"$ref":"#/$defs/MessageC"}],
             "$defs":{
                "MessageA":{"type":"object","properties":{"a":{"type":"string"}}},
                "MessageC":{"type":"object","properties":{"c":{"type":"string"}}}}}
            """))
    }

    @Test("test_with_pruning_messages_internal_reachability")
    func pruningMessagesReachability() {
        let result = prune(
            s2c: """
            {"oneOf":[{"$ref":"#/$defs/MessageA"}],
             "$defs":{
                "MessageA":{"type":"object","properties":{"shared":{"$ref":"#/$defs/SharedType"}}},
                "SharedType":{"type":"string"},
                "UnusedType":{"type":"number"}}}
            """,
            allowedMessages: ["MessageA"]
        )
        #expect(result.serverToClient == parse("""
            {"oneOf":[{"$ref":"#/$defs/MessageA"}],
             "$defs":{
                "MessageA":{"type":"object","properties":{"shared":{"$ref":"#/$defs/SharedType"}}},
                "SharedType":{"type":"string"}}}
            """))
    }

    @Test("test_with_pruning_common_types (components 連動)")
    func pruningCommonTypesViaComponents() {
        let result = prune(
            catalog: """
            {"catalogId":"basic","components":{
                "CompA":{"$ref":"common_types.json#/$defs/TypeForCompA"},
                "CompB":{"$ref":"common_types.json#/$defs/TypeForCompB"}}}
            """,
            common: ##"{"$defs":{"TypeForCompA":{"type":"string"},"TypeForCompB":{"type":"number"}}}"##,
            allowedComponents: ["CompA"]
        )
        #expect(result.commonTypes == parse(##"{"$defs":{"TypeForCompA":{"type":"string"}}}"##))
    }

    @Test("test_with_pruning_s2c_also_prunes_common_types")
    func pruningCommonTypesViaMessages() {
        let result = prune(
            s2c: """
            {"oneOf":[{"$ref":"#/$defs/MessageA"},{"$ref":"#/$defs/MessageB"}],
             "$defs":{
                "MessageA":{"$ref":"common_types.json#/$defs/TypeForA"},
                "MessageB":{"$ref":"common_types.json#/$defs/TypeForB"}}}
            """,
            common: ##"{"$defs":{"TypeForA":{"type":"string"},"TypeForB":{"type":"number"}}}"##,
            allowedMessages: ["MessageA"]
        )
        #expect(result.commonTypes == parse(##"{"$defs":{"TypeForA":{"type":"string"}}}"##))
    }

    @Test("test_with_pruning_messages_v08 (properties 直下)")
    func pruningMessagesV08() {
        let result = prune(
            s2c: """
            {"properties":{
                "beginRendering":{"type":"object"},
                "surfaceUpdate":{"type":"object"},
                "deleteSurface":{"type":"object"}},
             "required":["surfaceId"]}
            """,
            allowedMessages: ["beginRendering", "deleteSurface"]
        )
        #expect(result.serverToClient == parse("""
            {"properties":{
                "beginRendering":{"type":"object"},
                "deleteSurface":{"type":"object"}},
             "required":["surfaceId"]}
            """))
    }

    @Test("空 allowlist は no-op（公式 `if not allowed: return self`）")
    func emptyAllowlistsAreNoOps() {
        let catalog = ##"{"catalogId":"basic","components":{"Text":{}}}"##
        let s2c = ##"{"oneOf":[{"$ref":"#/$defs/MessageA"}],"$defs":{"MessageA":{}}}"##
        let result = prune(catalog: catalog, s2c: s2c, allowedComponents: [], allowedMessages: [])
        #expect(result.catalog == parse(catalog))
        #expect(result.serverToClient == parse(s2c))
    }

    @Test("存在しない名前の指定は黙って無視される")
    func unknownNamesAreIgnored() {
        let result = prune(
            catalog: ##"{"catalogId":"basic","components":{"Text":{}}}"##,
            allowedComponents: ["Text", "Ghost"]
        )
        #expect(result.catalog == parse(##"{"catalogId":"basic","components":{"Text":{}}}"##))
    }

    // MARK: - render (test_render_as_llm_instructions)

    @Test("test_render_as_llm_instructions")
    func renderAsLLMInstructions() {
        let output = SchemaBlockFormatter.format(
            serverToClientSchema: ##"{"s2c":"schema"}"##,
            commonTypesSchema: ##"{"$defs":{"common":"types"}}"##,
            catalogSchema: ##"{"$schema":"https://json-schema.org/draft/2020-12/schema","catalog":"schema","catalogId":"id_basic"}"##
        )
        let expected = """
        ---BEGIN A2UI JSON SCHEMA---

        ### Server To Client Schema:
        {"s2c":"schema"}

        ### Common Types Schema:
        {"$defs":{"common":"types"}}

        ### Catalog Schema:
        {"$schema":"https://json-schema.org/draft/2020-12/schema","catalog":"schema","catalogId":"id_basic"}

        ---END A2UI JSON SCHEMA---
        """
        #expect(output == expected)
    }

    @Test("test_render_as_llm_instructions_drops_empty_common_types")
    func renderDropsEmptyCommonTypes() {
        let output = SchemaBlockFormatter.format(
            serverToClientSchema: ##"{"s2c":"schema"}"##,
            commonTypesSchema: "{}",
            catalogSchema: ##"{"$schema":"https://json-schema.org/draft/2020-12/schema","catalog":"schema","catalogId":"id_basic"}"##
        )
        let expected = """
        ---BEGIN A2UI JSON SCHEMA---

        ### Server To Client Schema:
        {"s2c":"schema"}

        ### Catalog Schema:
        {"$schema":"https://json-schema.org/draft/2020-12/schema","catalog":"schema","catalogId":"id_basic"}

        ---END A2UI JSON SCHEMA---
        """
        #expect(output == expected)
    }
}

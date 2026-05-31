import A2UICore
import Foundation
import Testing
@testable import A2UIPrompt

@Suite("SchemaPruner.collectRefs")
struct CollectRefsTests {

    @Test("collects $ref values from nested objects and arrays")
    func collectsNestedRefs() throws {
        let json = """
        {
            "a": {"$ref": "#/$defs/Foo"},
            "b": [{"$ref": "#/$defs/Bar"}, {"x": {"$ref": "#/$defs/Baz"}}],
            "c": "no-ref-here"
        }
        """
        let value = try decode(json)
        let refs = SchemaPruner.collectRefs(in: value)
        #expect(refs == ["#/$defs/Foo", "#/$defs/Bar", "#/$defs/Baz"])
    }

    @Test("non-string $ref values are ignored")
    func ignoresNonStringRefs() throws {
        let json = """
        {"$ref": 42, "valid": {"$ref": "#/$defs/Real"}}
        """
        let refs = SchemaPruner.collectRefs(in: try decode(json))
        #expect(refs == ["#/$defs/Real"])
    }
}

@Suite("SchemaPruner.pruneMessages")
struct PruneMessagesTests {

    @Test("filters oneOf and prunes $defs by reachability")
    func filtersOneOfAndDefs() throws {
        let json = """
        {
            "oneOf": [
                {"$ref": "#/$defs/CreateSurfaceMessage"},
                {"$ref": "#/$defs/UpdateComponentsMessage"},
                {"$ref": "#/$defs/UpdateDataModelMessage"},
                {"$ref": "#/$defs/DeleteSurfaceMessage"}
            ],
            "$defs": {
                "CreateSurfaceMessage": {"type": "object", "properties": {"createSurface": {"$ref": "#/$defs/CreateSurface"}}},
                "CreateSurface": {"type": "object"},
                "UpdateComponentsMessage": {"type": "object"},
                "UpdateDataModelMessage": {"type": "object", "properties": {"updateDataModel": {"$ref": "#/$defs/DataModel"}}},
                "DataModel": {"type": "object"},
                "DeleteSurfaceMessage": {"type": "object"}
            }
        }
        """
        let value = try decode(json)
        let pruned = SchemaPruner.pruneMessages(
            serverToClient: value,
            allowedMessages: ["CreateSurfaceMessage", "UpdateComponentsMessage"]
        )
        guard case .object(let root) = pruned,
              case .array(let oneOf)? = root["oneOf"],
              case .object(let defs)? = root["$defs"] else {
            Issue.record("unexpected shape")
            return
        }
        // oneOf に残るのは 2 つ
        #expect(oneOf.count == 2)
        // $defs に残るのは CreateSurfaceMessage + 推移参照の CreateSurface + UpdateComponentsMessage
        #expect(Set(defs.keys) == ["CreateSurfaceMessage", "CreateSurface", "UpdateComponentsMessage"])
        #expect(defs["UpdateDataModelMessage"] == nil)
        #expect(defs["DataModel"] == nil)
        #expect(defs["DeleteSurfaceMessage"] == nil)
    }
}

@Suite("SchemaPruner.pruneCommonTypes")
struct PruneCommonTypesTests {

    @Test("keeps only $defs referenced by external schemas, transitively")
    func prunesByExternalRefs() throws {
        let common = try decode("""
        {
            "$defs": {
                "Used": {"type": "string"},
                "UsedIndirect": {"$ref": "https://x/common_types.json#/$defs/InnerDep"},
                "InnerDep": {"type": "object"},
                "Orphan": {"type": "object"}
            }
        }
        """)
        let catalog = try decode("""
        {"components": {"Foo": {"$ref": "https://x/common_types.json#/$defs/Used"}}}
        """)
        let s2c = try decode("""
        {"x": {"$ref": "https://x/common_types.json#/$defs/UsedIndirect"}}
        """)
        let pruned = SchemaPruner.pruneCommonTypes(
            commonTypes: common,
            reachableFrom: [catalog, s2c]
        )
        guard case .object(let root) = pruned,
              case .object(let defs)? = root["$defs"] else {
            Issue.record("unexpected shape")
            return
        }
        // Used (catalog 直接), UsedIndirect (s2c 直接), InnerDep (UsedIndirect から推移)
        #expect(Set(defs.keys) == ["Used", "UsedIndirect", "InnerDep"])
        #expect(defs["Orphan"] == nil)
    }

    @Test("returns input unchanged when $defs is missing")
    func noopWithoutDefs() throws {
        let common = try decode(#"{"description": "nothing here"}"#)
        let pruned = SchemaPruner.pruneCommonTypes(
            commonTypes: common,
            reachableFrom: []
        )
        #expect(pruned == common)
    }
}

// MARK: - Helpers

private func decode(_ json: String) throws -> StructuredValue {
    try JSONDecoder().decode(StructuredValue.self, from: Data(json.utf8))
}

import Testing
@testable import A2UIAGUI
import AGUICore
import StructuredDataCore
import Foundation

@Suite("A2UISchemaContext: カタログ宣言の複数抽出")
struct A2UISchemaDeclarationsTests {

    private let componentsV1: StructuredValue = .object([
        "Text": .object(["type": .string("object")]),
        "DelishRecipeCard": .object(["type": .string("object")]),
    ])

    @Test("declaration → declarations のラウンドトリップ")
    func roundTrip() throws {
        let entry = try A2UISchemaContext.declaration(
            catalogId: "https://example.com/catalogs/delish/v1/catalog.json",
            components: componentsV1
        )
        let parsed = A2UISchemaContext.declarations(in: [entry])
        #expect(parsed.count == 1)
        #expect(parsed[0].catalogId == "https://example.com/catalogs/delish/v1/catalog.json")
        #expect(parsed[0].componentNames == ["Text", "DelishRecipeCard"])
        #expect(parsed[0].components == componentsV1)
    }

    @Test("複数宣言は出現順(preference 順)を保つ")
    func multipleDeclarationsPreserveOrder() throws {
        let v2 = try A2UISchemaContext.declaration(
            catalogId: "https://example.com/catalogs/delish/v2/catalog.json",
            components: .object(["Text": .object([:])])
        )
        let v1 = try A2UISchemaContext.declaration(
            catalogId: "https://example.com/catalogs/delish/v1/catalog.json",
            components: componentsV1
        )
        let other = AGUIContext(description: "generation guidelines", value: "be nice")
        let parsed = A2UISchemaContext.declarations(in: [v2, other, v1])
        #expect(parsed.map(\.catalogId) == [
            "https://example.com/catalogs/delish/v2/catalog.json",
            "https://example.com/catalogs/delish/v1/catalog.json",
        ])
    }

    @Test("空 components / 空 catalogId の宣言は除外する")
    func emptyDeclarationsAreFiltered() throws {
        let emptyComponents = try A2UISchemaContext.declaration(
            catalogId: "https://example.com/catalogs/x/v1/catalog.json",
            components: .object([:])
        )
        let emptyCatalogId = try A2UISchemaContext.declaration(
            catalogId: "",
            components: componentsV1
        )
        #expect(A2UISchemaContext.declarations(in: [emptyComponents, emptyCatalogId]).isEmpty)
    }

    @Test("壊れた JSON・無関係な description は無視する")
    func malformedAndUnrelatedEntriesAreIgnored() {
        let malformed = AGUIContext(
            description: A2UIAGUIConstants.schemaContextDescription,
            value: "{not json"
        )
        let unrelated = AGUIContext(description: "something else", value: "{}")
        #expect(A2UISchemaContext.declarations(in: [malformed, unrelated]).isEmpty)
    }

    @Test("declaredCatalogId は components 無しの値でも catalogId を返す(公式のフォールバック解決)")
    func declaredCatalogIdIgnoresComponents() {
        let entry = AGUIContext(
            description: A2UIAGUIConstants.schemaContextDescription,
            value: #"{"catalogId":"https://example.com/catalogs/x/v1/catalog.json"}"#
        )
        #expect(A2UISchemaContext.declaredCatalogId(in: [entry])
            == "https://example.com/catalogs/x/v1/catalog.json")
        #expect(A2UISchemaContext.declarations(in: [entry]).isEmpty)
    }
}

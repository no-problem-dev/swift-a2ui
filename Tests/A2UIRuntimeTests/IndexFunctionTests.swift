import A2UICore
import A2UISurface
import Foundation
import Testing

@testable import A2UIRuntime

/// A2UI v1.0 の組み込み `@index`。
///
/// 仕様: テンプレート反復（Collection Scope）中の 0 始まりの添字を返す。`offset` で加算できる。
/// **反復の外での呼び出しは評価エラー**であり、`@` プレフィックスはコアのシステム評価に予約されている。
@Suite("v1.0 built-in @index")
struct IndexFunctionTests {

    private func context(index: Int?) -> DataContext {
        DataContext(
            dataModel: DataModel(),
            path: "/items/0",
            collectionIndex: index,
            functions: BasicFunctions()
        )
    }

    @Test("returns the 0-based iteration index")
    func returnsIndex() {
        let fns = BasicFunctions()
        #expect(fns.evaluate(.index(), in: context(index: 0)) == .int(0))
        #expect(fns.evaluate(.index(), in: context(index: 3)) == .int(3))
    }

    @Test("offset shifts the index (offset 1 gives 1-based numbering)")
    func offsetShiftsIndex() {
        let fns = BasicFunctions()
        #expect(fns.evaluate(.index(offset: 1), in: context(index: 0)) == .int(1))
        #expect(fns.evaluate(.index(offset: 10), in: context(index: 2)) == .int(12))
    }

    @Test("outside a template iteration it does not evaluate (spec: evaluation error)")
    func unresolvedOutsideCollectionScope() {
        #expect(BasicFunctions().evaluate(.index(), in: context(index: nil)) == nil)
    }

    @Test("decodes from the wire and resolves through a DynamicString")
    func resolvesThroughDynamicValue() throws {
        let value = try JSONDecoder().decode(
            DynamicString.self, from: Data(#"{"call":"@index","args":{"offset":1}}"#.utf8))
        #expect(context(index: 4).resolveString(value) == "5")
    }
}

/// テンプレート展開が反復の添字を配るところ（`@index` の供給元）。
@Suite("v1.0 template expansion carries the collection index")
struct TemplateCollectionIndexTests {

    @Test("array templates number their instances in order")
    func arrayTemplateIndexes() {
        let model = DataModel()
        model.set("/items", .array([.string("a"), .string("b"), .string("c")]))
        let children = TemplateExpander.expand(
            .template(componentId: "row", path: "/items"),
            in: DataContext(dataModel: model)
        )
        #expect(children.map(\.collectionIndex) == [0, 1, 2])
        #expect(children.map(\.basePath) == ["/items/0", "/items/1", "/items/2"])
    }

    @Test("object templates number their instances in stable key order")
    func objectTemplateIndexes() {
        let model = DataModel()
        model.set("/byKey", .object(["b": .string("2"), "a": .string("1")]))
        let children = TemplateExpander.expand(
            .template(componentId: "row", path: "/byKey"),
            in: DataContext(dataModel: model)
        )
        #expect(children.map(\.collectionIndex) == [0, 1])
        #expect(children.map(\.basePath) == ["/byKey/a", "/byKey/b"])
    }

    @Test("a static id list is not an iteration — no index, so @index stays unevaluated")
    func staticListHasNoIndex() {
        let children = TemplateExpander.expand(
            .ids(["a", "b"]),
            in: DataContext(dataModel: DataModel())
        )
        #expect(children.allSatisfy { $0.collectionIndex == nil })
    }
}

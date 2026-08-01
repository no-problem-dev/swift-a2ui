import A2UICatalog
import A2UICore
import Foundation
import Testing

@testable import A2UITyped

/// A2UI v1.0 §Processing rules — コンポーネント／関数呼び出しのカタログ解決順序。
///
/// 1. コンポーネント（呼び出し）自身の `catalogId`
/// 2. サーフェス既定の `catalogId`
/// 3. どちらも無ければエラー（描画しない）。capabilities へのフォールバックは**しない**。
@Suite("v1.0 catalog resolution order")
struct CatalogResolutionTests {

    private let basic = "https://a2ui.org/specification/v1_0/catalogs/basic/catalog.json"
    private let mine = "mycompany.com:somecatalog"

    @Test("component-level catalogId wins over the surface default")
    func componentOverridesSurface() {
        #expect(
            CatalogResolution.resolve(declared: mine, surfaceDefault: basic)
                == .resolved(catalogId: mine)
        )
    }

    @Test("falls back to the surface default when the component declares none")
    func fallsBackToSurfaceDefault() {
        #expect(
            CatalogResolution.resolve(declared: nil, surfaceDefault: basic)
                == .resolved(catalogId: basic)
        )
    }

    @Test("neither declared nor default → unresolved (the component must not render)")
    func neitherIsAnError() {
        #expect(CatalogResolution.resolve(declared: nil, surfaceDefault: nil) == .unresolved)
        #expect(CatalogResolution.resolve(declared: "", surfaceDefault: "") == .unresolved)
    }

    @Test("a catalog the renderer does not support stays unresolved (no capabilities fallback)")
    func unsupportedCatalogIsUnresolved() {
        #expect(
            CatalogResolution.resolve(declared: mine, surfaceDefault: basic, supported: [basic])
                == .unresolved
        )
        #expect(
            CatalogResolution.resolve(declared: mine, surfaceDefault: basic, supported: [basic, mine])
                == .resolved(catalogId: mine)
        )
    }

    @Test("an empty supported set skips the support check")
    func emptySupportedSetSkipsCheck() {
        #expect(
            CatalogResolution.resolve(declared: mine, surfaceDefault: nil, supported: [])
                == .resolved(catalogId: mine)
        )
    }

    // MARK: - Wire-level

    @Test("a node's declared catalogId is read off the wire")
    func nodeDeclaredCatalogId() throws {
        let json = #"{"id":"t1","component":"Text","text":"hi","catalogId":"mycompany.com:somecatalog"}"#
        let node = try JSONDecoder().decode(CatalogNode<BasicComponent>.self, from: Data(json.utf8))
        #expect(node.declaredCatalogId == mine)
        #expect(node.resolveCatalog(surfaceDefault: basic) == .resolved(catalogId: mine))
    }

    @Test("a node without catalogId inherits the surface default")
    func nodeInheritsSurfaceDefault() throws {
        let json = #"{"id":"t1","component":"Text","text":"hi"}"#
        let node = try JSONDecoder().decode(CatalogNode<BasicComponent>.self, from: Data(json.utf8))
        #expect(node.declaredCatalogId == nil)
        #expect(node.resolveCatalog(surfaceDefault: basic) == .resolved(catalogId: basic))
        #expect(node.resolveCatalog(surfaceDefault: nil) == .unresolved)
    }

    @Test("an unknown component still exposes its catalogId (it explains the miss)")
    func unknownComponentCatalogId() throws {
        let json = #"{"id":"x","component":"NotInThisCatalog","catalogId":"mycompany.com:somecatalog"}"#
        let node = try JSONDecoder().decode(CatalogNode<BasicComponent>.self, from: Data(json.utf8))
        #expect(node.declaredCatalogId == mine)
    }

    @Test("system functions (@index) belong to no catalog and always resolve")
    func systemFunctionsNeedNoCatalog() {
        #expect(FunctionCall.index().resolveCatalog(surfaceDefault: nil) == .resolved(catalogId: ""))
        // A normal catalog function still needs one.
        #expect(FunctionCall(call: "openUrl").resolveCatalog(surfaceDefault: nil) == .unresolved)
        #expect(
            FunctionCall(call: "openUrl").resolveCatalog(surfaceDefault: basic)
                == .resolved(catalogId: basic)
        )
    }
}

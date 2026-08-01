import A2UICore

/// コンポーネント／関数呼び出しをどのカタログで解釈するかの決定（A2UI v1.0 §Processing rules）。
///
/// v1.0 で 1 枚のサーフェスに複数カタログを混在させられるようになり、解決順序が明文化された:
///
/// 1. コンポーネント（または関数呼び出し）自身の `catalogId`
/// 2. 無ければサーフェス既定の `catalogId`（`createSurface` が持つもの）
/// 3. どちらも無ければ**エラー**。そのコンポーネントは描画しない（関数呼び出しは失敗させる）
///
/// capabilities で宣言したカタログへのフォールバックは**しない** — 仕様が明示的に禁じている。
public enum CatalogResolution: Sendable, Equatable {
    /// 解決できた。`catalogId` がこのコンポーネント／呼び出しを解釈するカタログ。
    case resolved(catalogId: String)
    /// コンポーネントにも surface にも `catalogId` が無い。描画してはならない。
    case unresolved

    /// 解決済みのカタログ ID（未解決なら `nil`）。
    public var catalogId: String? {
        if case .resolved(let id) = self { return id }
        return nil
    }

    /// v1.0 の解決順序を適用する。
    ///
    /// - Parameters:
    ///   - declared: コンポーネント／関数呼び出しが明示した `catalogId`。
    ///   - surfaceDefault: `createSurface` が定めたサーフェス既定の `catalogId`。
    public static func resolve(
        declared: String?,
        surfaceDefault: String?
    ) -> CatalogResolution {
        if let declared, !declared.isEmpty { return .resolved(catalogId: declared) }
        if let surfaceDefault, !surfaceDefault.isEmpty { return .resolved(catalogId: surfaceDefault) }
        return .unresolved
    }

    /// レンダラーが対応しているカタログの範囲まで含めて解決する。
    ///
    /// 解決した ID が `supported` に無い場合も `unresolved` を返す — 知らないカタログの
    /// コンポーネントは描画できない。`supported` が空なら対応集合の検査は行わない。
    public static func resolve(
        declared: String?,
        surfaceDefault: String?,
        supported: Set<String>
    ) -> CatalogResolution {
        let resolution = resolve(declared: declared, surfaceDefault: surfaceDefault)
        guard case .resolved(let id) = resolution else { return .unresolved }
        if supported.isEmpty || supported.contains(id) { return resolution }
        return .unresolved
    }
}

extension CatalogNode {
    /// このノードのカタログを v1.0 の順序で解決する（→ `CatalogResolution`）。
    public func resolveCatalog(surfaceDefault: String?) -> CatalogResolution {
        CatalogResolution.resolve(declared: declaredCatalogId, surfaceDefault: surfaceDefault)
    }
}

extension FunctionCall {
    /// この関数呼び出しのカタログを v1.0 の順序で解決する。
    ///
    /// 組み込みのシステム関数（`@index` など）はカタログに属さないため、常に解決済みとして扱う。
    public func resolveCatalog(surfaceDefault: String?) -> CatalogResolution {
        if isSystemFunction { return .resolved(catalogId: "") }
        return CatalogResolution.resolve(declared: catalogId, surfaceDefault: surfaceDefault)
    }
}

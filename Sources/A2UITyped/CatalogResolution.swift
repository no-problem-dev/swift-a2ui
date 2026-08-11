import A2UICore

/// Which catalog interprets a component or function call (A2UI v1.0 §Processing rules).
///
/// v1.0 allows several catalogs on one surface, so the resolution order is spelled out:
///
/// 1. The `catalogId` on the component (or function call) itself.
/// 2. Failing that, the surface default `catalogId` carried by `createSurface`.
/// 3. With neither, it is an **error**: do not render the component (fail the function call).
///
/// There is **no** fallback to a catalog declared in capabilities — the spec forbids it outright.
public enum CatalogResolution: Sendable, Equatable {
    /// The catalog that interprets this component or call was determined.
    case resolved(catalogId: String)
    /// Neither the component nor the surface names a catalog; the component must not be rendered.
    case unresolved

    /// The resolved catalog id, or `nil` when unresolved — treat `nil` as "drop it", never as "guess".
    public var catalogId: String? {
        if case .resolved(let id) = self { return id }
        return nil
    }

    /// Applies the v1.0 resolution order. An empty string counts as absent, not as a catalog named "".
    ///
    /// - Parameters:
    ///   - declared: The `catalogId` the component or function call states for itself.
    ///   - surfaceDefault: The surface-wide `catalogId` established by `createSurface`.
    public static func resolve(
        declared: String?,
        surfaceDefault: String?
    ) -> CatalogResolution {
        if let declared, !declared.isEmpty { return .resolved(catalogId: declared) }
        if let surfaceDefault, !surfaceDefault.isEmpty { return .resolved(catalogId: surfaceDefault) }
        return .unresolved
    }

    /// Resolves, then narrows the result to the catalogs this renderer actually supports.
    ///
    /// An id that resolves but is missing from `supported` also comes back `unresolved` — a component
    /// from an unknown catalog cannot be drawn. An empty `supported` skips the support check entirely.
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
    /// Resolves this node's catalog in the v1.0 order: its own `catalogId` first, then `surfaceDefault`.
    public func resolveCatalog(surfaceDefault: String?) -> CatalogResolution {
        CatalogResolution.resolve(declared: declaredCatalogId, surfaceDefault: surfaceDefault)
    }
}

extension FunctionCall {
    /// Resolves this call's catalog in the v1.0 order.
    ///
    /// Built-in system functions such as `@index` belong to no catalog, so they always come back
    /// resolved (with an empty id) and are never rejected for lack of a surface default.
    public func resolveCatalog(surfaceDefault: String?) -> CatalogResolution {
        if isSystemFunction { return .resolved(catalogId: "") }
        return CatalogResolution.resolve(declared: catalogId, surfaceDefault: surfaceDefault)
    }
}

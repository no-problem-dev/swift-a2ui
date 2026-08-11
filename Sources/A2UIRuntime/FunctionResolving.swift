import StructuredDataCore
import A2UICore

/// The hook that evaluates a `FunctionCall` while a dynamic value is being resolved.
///
/// `DataContext` depends on this protocol alone, which keeps binding resolution independent of the
/// function registry: the Basic Catalog functions (`formatString`, `required`, …) are supplied from the
/// outside by `BasicFunctions`.
public protocol FunctionResolving: Sendable {
    /// Evaluates a function call in the given data context.
    ///
    /// - Returns: The result, or `nil` when the function is unknown, returns void (`openUrl`), or cannot
    ///   evaluate here at all (`@index` outside a template iteration). Callers coerce `nil` through the
    ///   spec's type table — `""`, `false`, `0` — so an unresolved call reads as an empty value, not an
    ///   error.
    func evaluate(_ call: FunctionCall, in context: DataContext) -> StructuredValue?
}

/// A resolver that evaluates every function call to `nil`.
///
/// The `DataContext` default when no registry is injected. With it in place a `formatString` binding
/// renders as the empty string rather than failing, so use it only for a surface that is not expected to
/// call functions.
public struct NoFunctionResolver: FunctionResolving {
    public init() {}
    public func evaluate(_ call: FunctionCall, in context: DataContext) -> StructuredValue? { nil }
}

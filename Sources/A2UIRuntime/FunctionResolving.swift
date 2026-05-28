import A2UICore

/// Hook for evaluating `FunctionCall`s during dynamic-value resolution.
///
/// The actual function registry (Basic Catalog functions: `formatString`, `required`, ...) is
/// implemented in Step 3. `DataContext` depends only on this narrow protocol so that Step 2
/// (binding resolution) and Step 3 (functions) stay decoupled.
public protocol FunctionResolving: Sendable {
    /// Evaluate a function call within the given data context, returning its result (or nil).
    func evaluate(_ call: FunctionCall, in context: DataContext) -> AnyCodable?
}

/// A no-op resolver: every function call resolves to nil.
/// Used as the default until the Basic Catalog function registry is wired in (Step 3).
public struct NoFunctionResolver: FunctionResolving {
    public init() {}
    public func evaluate(_ call: FunctionCall, in context: DataContext) -> AnyCodable? { nil }
}

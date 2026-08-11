import StructuredDataCore
/// Who may invoke a function (A2UI v1.0 `callableFrom`).
///
/// It never travels with a `FunctionCall`: it is static metadata on the catalog's
/// `FunctionDefinition`, which is why the renderer has to look the name up at call time rather than
/// trust the message (see `FunctionBoundary`). Omitting it in a catalog means `rendererOnly`.
public enum CallableFrom: String, Codable, Sendable, Equatable {
    case rendererOnly
    case agentOnly
    case rendererOrAgent
}

/// A call to a catalog function by name, with its arguments (A2UI v1.0).
///
/// `call` is the function name and `args` a map keyed by argument name. Neither `callableFrom` nor
/// `returnType` is part of this type — both are static metadata on the catalog's
/// `FunctionDefinition` — so a call carries no proof that it is allowed and the receiver must
/// consult the catalog itself.
public struct FunctionCall: Codable, Sendable, Equatable {
    public let call: String
    /// Catalog this name is resolved in, overriding the surface default from
    /// `CreateSurface.catalogId`.
    public let catalogId: String?
    public let args: [String: StructuredValue]?

    public init(
        call: String,
        catalogId: String? = nil,
        args: [String: StructuredValue]? = nil
    ) {
        self.call = call
        self.catalogId = catalogId
        self.args = args
    }
}

extension FunctionCall {
    /// Name of the built-in `@index` function. The `@` prefix is reserved for evaluation by the
    /// core, so a catalog cannot define or override it.
    public static let indexFunctionName = "@index"

    /// Builds a call to the built-in `@index`, which yields the zero-based position of the current
    /// template iteration.
    ///
    /// It only evaluates while a template is being instantiated; outside one there is no iteration
    /// to number and the call is an evaluation error.
    ///
    /// - Parameter offset: Added to the index — pass `1` to number items from one. Defaults to `0`.
    public static func index(offset: Int? = nil) -> FunctionCall {
        FunctionCall(
            call: indexFunctionName,
            args: offset.map { ["offset": StructuredValue(integerLiteral: $0)] }
        )
    }

    /// `true` for a name beginning with `@`, which the core evaluates itself instead of looking it
    /// up in the catalog — check this before reporting an unknown function.
    public var isSystemFunction: Bool { call.hasPrefix("@") }
}

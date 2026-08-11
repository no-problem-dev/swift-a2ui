import StructuredDataCore
import A2UICore

/// A type-safe description of one catalog function, rendered into the `functions` block of the
/// catalog document (spec §7).
public struct FunctionSchema: Sendable, Equatable {
    public let name: String
    public let description: String?
    public let arguments: [PropertySchema]
    /// A raw `args` object that replaces `arguments` when set. Several official functions have
    /// argument shapes the property list cannot express — `anyOf`, `additionalProperties`, a `$ref`
    /// carrying its own `description` — and those must be reproduced exactly.
    public let argsObject: StructuredValue?
    /// Constant naming what the function yields: `"string"`, `"number"`, `"boolean"`, `"void"`.
    ///
    /// In v1.0 this is static catalog metadata; it no longer rides on the wire inside
    /// `FunctionCall`.
    public let returnType: String
    /// Where the function may be called from — `rendererOnly`, `agentOnly`, or `rendererOrAgent`
    /// (v1.0). `nil` is read as `rendererOnly`, and the boundary is enforced at run time by looking
    /// the function up in the catalog.
    public let callableFrom: String?

    public init(
        name: String,
        description: String? = nil,
        arguments: [PropertySchema] = [],
        argsObject: StructuredValue? = nil,
        returnType: String,
        callableFrom: String? = nil
    ) {
        self.name = name
        self.description = description
        self.arguments = arguments
        self.argsObject = argsObject
        self.returnType = returnType
        self.callableFrom = callableFrom
    }
}

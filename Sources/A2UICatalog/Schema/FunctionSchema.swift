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
    /// What the function yields.
    ///
    /// In v1.0 this is static catalog metadata; it no longer rides on the wire inside
    /// `FunctionCall`. Typed rather than spelled as a `String`, so a misspelling is a compile error
    /// instead of a word the model reads out of the prompt and believes.
    public let returnType: FunctionReturnType
    /// Where the function may be called from. `nil` is read as `rendererOnly`, and the boundary is
    /// enforced at run time by `FunctionBoundary` looking the function up in the catalog — which is
    /// only possible because this is the protocol's own enum and not free-form text.
    public let callableFrom: CallableFrom?

    public init(
        name: String,
        description: String? = nil,
        arguments: [PropertySchema] = [],
        argsObject: StructuredValue? = nil,
        returnType: FunctionReturnType,
        callableFrom: CallableFrom? = nil
    ) {
        self.name = name
        self.description = description
        self.arguments = arguments
        self.argsObject = argsObject
        self.returnType = returnType
        self.callableFrom = callableFrom
    }
}

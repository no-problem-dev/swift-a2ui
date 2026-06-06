import A2UICore

/// A type-safe description of a catalog function's contract (spec §7 functions block).
public struct FunctionSchema: Sendable, Equatable {
    public let name: String
    public let description: String?
    public let arguments: [PropertySchema]
    /// Verbatim `args` object (overrides `arguments` when set). Reproduces the official catalog's
    /// irregular function-arg shapes exactly (`anyOf`, `additionalProperties`, `$ref`+description
    /// args, `format`/`minimum`/`minItems`, description-only args).
    public let argsObject: StructuredValue?
    /// Return type const: "string" / "number" / "boolean" / "void" / ...
    public let returnType: String

    public init(
        name: String,
        description: String? = nil,
        arguments: [PropertySchema] = [],
        argsObject: StructuredValue? = nil,
        returnType: String
    ) {
        self.name = name
        self.description = description
        self.arguments = arguments
        self.argsObject = argsObject
        self.returnType = returnType
    }
}

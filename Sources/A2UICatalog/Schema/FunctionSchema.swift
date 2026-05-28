/// A type-safe description of a catalog function's contract (spec §7 functions block).
public struct FunctionSchema: Sendable, Equatable {
    public let name: String
    public let description: String?
    public let arguments: [PropertySchema]
    /// Return type const: "string" / "number" / "boolean" / "any" / "void" / ...
    public let returnType: String

    public init(
        name: String,
        description: String? = nil,
        arguments: [PropertySchema],
        returnType: String
    ) {
        self.name = name
        self.description = description
        self.arguments = arguments
        self.returnType = returnType
    }
}

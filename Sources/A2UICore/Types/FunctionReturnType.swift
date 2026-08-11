/// The type a catalog function declares it produces (A2UI v1.0 `returnType`).
///
/// It describes the function, not any one call: it lives on the catalog's `FunctionDefinition` and
/// never reaches a `FunctionCall`. Renderers coerce whatever comes back to what the property needs,
/// so this is documentation for the agent rather than a guarantee enforced at render time.
public enum FunctionReturnType: String, Codable, Sendable, Equatable, Hashable {
    case string
    case number
    case boolean
    case array
    case object
    case void
}

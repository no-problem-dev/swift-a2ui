/// Formats three JSON schema strings into the official A2UI schema block.
///
/// The block is delimited by `---BEGIN A2UI JSON SCHEMA---` and
/// `---END A2UI JSON SCHEMA---`, with each schema on a labelled line,
/// matching the Python SDK's output exactly.
public enum SchemaBlockFormatter {
    /// Opening delimiter for the schema block.
    public static let beginMarker = "---BEGIN A2UI JSON SCHEMA---"
    /// Closing delimiter for the schema block.
    public static let endMarker = "---END A2UI JSON SCHEMA---"

    /// Assemble the three schemas into the official schema block string.
    ///
    /// - Parameters:
    ///   - serverToClientSchema: JSON string for the server-to-client schema.
    ///   - commonTypesSchema: JSON string for the common types schema.
    ///   - catalogSchema: JSON string for the component catalog schema.
    /// - Returns: A multi-line string in the official A2UI schema block format.
    public static func format(
        serverToClientSchema: String,
        commonTypesSchema: String,
        catalogSchema: String
    ) -> String {
        var sections: [String] = [beginMarker]
        sections.append("### Server To Client Schema:\n\(serverToClientSchema)")
        if !commonTypesSchema.isEmpty, commonTypesSchema != "{}" {
            sections.append("### Common Types Schema:\n\(commonTypesSchema)")
        }
        sections.append("### Catalog Schema:\n\(catalogSchema)")
        sections.append(endMarker)
        return sections.joined(separator: "\n\n")
    }
}

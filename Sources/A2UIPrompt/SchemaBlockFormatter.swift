/// Lays three JSON schema strings out as the official A2UI schema block.
///
/// The block is delimited by `---BEGIN A2UI JSON SCHEMA---` and `---END A2UI JSON SCHEMA---`,
/// each schema under its own labelled heading — byte for byte the layout the Python SDK emits,
/// which is what lets a prompt built here be compared against the official one.
public enum SchemaBlockFormatter {
    /// The line that opens the schema block; match on it to find the block inside a prompt.
    public static let beginMarker = "---BEGIN A2UI JSON SCHEMA---"
    /// The line that closes the schema block, paired with `beginMarker` to bound it.
    public static let endMarker = "---END A2UI JSON SCHEMA---"

    /// Assembles the three schemas into the official schema block.
    ///
    /// - Parameters:
    ///   - agentToRendererSchema: JSON string for the server-to-client schema.
    ///   - commonTypesSchema: JSON string for the common types schema. An empty string or `{}`
    ///     drops the section entirely — which is what pruning everything away produces, and
    ///     what a catalog with no shared types should emit rather than an empty heading.
    ///   - catalogSchema: JSON string for the component catalog schema.
    /// - Returns: The multi-line block, delimiters included, ready to append to a prompt.
    public static func format(
        agentToRendererSchema: String,
        commonTypesSchema: String,
        catalogSchema: String
    ) -> String {
        var sections: [String] = [beginMarker]
        sections.append("### Server To Client Schema:\n\(agentToRendererSchema)")
        if !commonTypesSchema.isEmpty, commonTypesSchema != "{}" {
            sections.append("### Common Types Schema:\n\(commonTypesSchema)")
        }
        sections.append("### Catalog Schema:\n\(catalogSchema)")
        sections.append(endMarker)
        return sections.joined(separator: "\n\n")
    }
}

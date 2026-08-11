import A2UICore
import Foundation

/// Assembles the sub-agent's system prompt.
///
/// Mirrors `buildSubagentPrompt` in `@ag-ui/a2ui-toolkit`. The section order is part of the
/// contract:
/// 1. Generation guidelines (no heading — plain text at the very top)
/// 2. `## Design Guidelines`
/// 3. `## Available Components` (the catalog schema)
/// 4. Composition guide (host-specific catalog knowledge)
///
/// The catalog definition is embedded **here, as text**, not in the tool's JSON Schema — the
/// same call upstream makes. The catalog is only known at runtime, a huge union runs into
/// provider schema limits, and `A2UIValidation` is what actually checks the structure.
public struct A2UISubagentPrompt: Sendable {
    private let guidelines: A2UIGuidelines
    private let catalogSchema: String?
    private let renderToolName: String

    public init(
        guidelines: A2UIGuidelines = .default,
        catalogSchema: String? = nil,
        renderToolName: String = A2UISubagentConstants.renderToolName
    ) {
        self.guidelines = guidelines
        self.catalogSchema = catalogSchema
        self.renderToolName = renderToolName
    }

    /// Joins the enabled guideline blocks with a blank line between them.
    ///
    /// A suppressed or empty block leaves no gap and no heading, so a host can drop a whole
    /// section without the prompt reading as if something went missing.
    public func render() -> String {
        var parts: [String] = []

        if let generation = guidelines.generation.resolve(
            default: A2UIDefaultGuidelines.generation(renderToolName: renderToolName)
        ) {
            parts.append(generation)
        }
        if let design = guidelines.design.resolve(default: A2UIDefaultGuidelines.design) {
            parts.append("## Design Guidelines\n\(design)")
        }
        if let catalogSchema, !catalogSchema.isEmpty {
            parts.append("## Available Components\n\(catalogSchema)")
        }
        if let composition = guidelines.composition, !composition.isEmpty {
            parts.append(composition)
        }

        return parts.joined(separator: "\n\n")
    }

}

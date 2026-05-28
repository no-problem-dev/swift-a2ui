import Foundation
import A2UICatalog

/// Builds LLM system prompts in the official Google A2UI format.
///
/// `A2UIPromptBuilder` assembles the four sections that the Python SDK
/// produces: role description, workflow rules, optional UI description,
/// and the JSON schema block (server-to-client, common types, catalog).
///
/// ### Example
/// ```swift
/// let builder = A2UIPromptBuilder()
/// let prompt = builder.buildSystemPrompt(
///     role: "You are a helpful assistant that renders UI.",
///     uiDescription: "Show a card with a title and a confirm button."
/// )
/// ```
public struct A2UIPromptBuilder: Sendable {

    // MARK: - Private storage (nil = use bundled resources at call time)

    private let _serverToClientSchema: String?
    private let _commonTypesSchema: String?
    private let _catalogSchema: String?

    // MARK: - Init

    /// Initialize using the schemas bundled with A2UIPrompt (server_to_client.json,
    /// common_types.json) and the catalog.json bundled with A2UICatalog.
    public init() {
        _serverToClientSchema = nil
        _commonTypesSchema = nil
        _catalogSchema = nil
    }

    /// Initialize with custom schema strings, bypassing the bundled resources.
    ///
    /// Useful for testing or when targeting a different A2UI spec version.
    public init(
        serverToClientSchema: String,
        commonTypesSchema: String,
        catalogSchema: String
    ) {
        _serverToClientSchema = serverToClientSchema
        _commonTypesSchema = commonTypesSchema
        _catalogSchema = catalogSchema
    }

    /// Initialize with a custom **catalog** schema while keeping the bundled server-to-client and
    /// common-types schemas. This is the common case for an app with a custom component catalog:
    /// generate the catalog schema from your Swift types (`SchemaRenderer`) and pass it here.
    public init(catalogSchema: String) {
        _serverToClientSchema = nil
        _commonTypesSchema = nil
        _catalogSchema = catalogSchema
    }

    // MARK: - Public API

    /// Build a complete system prompt in the official A2UI format.
    ///
    /// The prompt sections are joined with `\n\n` to produce clean spacing.
    /// Sections are assembled in this order:
    ///
    /// 1. `role` — required, describes the assistant's persona.
    /// 2. `## Workflow Description:` — workflow rules (default or custom).
    /// 3. `## UI Description:` — optional free-form UI description.
    /// 4. The JSON schema block — included when `includeSchema` is `true`.
    ///
    /// - Parameters:
    ///   - role: A description of the LLM's role / persona.
    ///   - workflowRules: Custom workflow rules. Pass `nil` to use
    ///     `A2UIWorkflowRules.default`.
    ///   - uiDescription: Optional description of the expected UI structure.
    ///   - includeSchema: Whether to append the JSON schema block.
    ///     Defaults to `true`.
    /// - Returns: A fully assembled system prompt string.
    public func buildSystemPrompt(
        role: String,
        workflowRules: String? = nil,
        uiDescription: String? = nil,
        examples: String? = nil,
        includeSchema: Bool = true
    ) -> String {
        var sections: [String] = [role]

        let rules = workflowRules ?? A2UIWorkflowRules.default
        sections.append("## Workflow Description:\n\(rules)")

        if let uiDescription {
            sections.append("## UI Description:\n\(uiDescription)")
        }

        if includeSchema {
            sections.append(schemaBlock())
        }

        if let examples {
            sections.append("### Examples:\n\(examples)")
        }

        return sections.joined(separator: "\n\n")
    }

    /// Build just the schema block portion of the prompt.
    ///
    /// The block is formatted by `SchemaBlockFormatter` and contains the
    /// server-to-client, common types, and catalog schemas.
    public func schemaBlock() -> String {
        SchemaBlockFormatter.format(
            serverToClientSchema: resolvedServerToClientSchema,
            commonTypesSchema: resolvedCommonTypesSchema,
            catalogSchema: resolvedCatalogSchema
        )
    }

    // MARK: - Schema resolution

    private var resolvedServerToClientSchema: String {
        _serverToClientSchema ?? Self.loadBundledResource("server_to_client")
    }

    private var resolvedCommonTypesSchema: String {
        _commonTypesSchema ?? Self.loadBundledResource("common_types")
    }

    private var resolvedCatalogSchema: String {
        _catalogSchema ?? BasicComponentCatalog.catalogSchemaJSON()
    }

    /// Load a JSON file from A2UIPrompt's own resource bundle.
    ///
    /// Tries the explicit `Resources/` subdirectory first (which matches the
    /// `.copy("Resources")` layout) and falls back to a flat lookup, which is
    /// the layout SwiftPM produces when `.process("Resources")` flattens the
    /// directory hierarchy.
    private static func loadBundledResource(_ name: String) -> String {
        let url = Bundle.module.url(forResource: name, withExtension: "json", subdirectory: "Resources")
            ?? Bundle.module.url(forResource: name, withExtension: "json")
        guard let url else {
            return "{}"
        }
        return (try? String(contentsOf: url, encoding: .utf8)) ?? "{}"
    }
}

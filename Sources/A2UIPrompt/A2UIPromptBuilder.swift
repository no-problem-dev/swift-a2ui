import StructuredDataCore
import Foundation
import A2UICatalog
import A2UICore
import JSONParsing

/// Assembles an LLM system prompt in the official Google A2UI format.
///
/// Produces the same four sections the Python SDK emits: the role description, the workflow
/// rules, an optional UI description, and the JSON schema block (server-to-client, common
/// types, catalog).
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

    private let _agentToRendererSchema: String?
    private let _commonTypesSchema: String?
    private let _catalogSchema: String?

    /// Catalog component names to keep, for example `["Text", "Button"]`.
    ///
    /// `nil` disables pruning and keeps every component the catalog declares. Public so that
    /// `SendA2UIToClientTool` can validate incoming payloads against the same allowlist the
    /// prompt was built from — the prompt and the enforcement must not drift apart.
    public let allowedComponents: Set<String>?

    /// Agent-to-renderer message type names to keep, for example `["CreateSurfaceMessage"]`.
    ///
    /// `nil` disables pruning and keeps every branch of the bundled `oneOf`. Public for the
    /// same reason as `allowedComponents`: the tool that validates the model's payload reads
    /// the allowlist from here, so what the prompt advertises is exactly what is accepted.
    public let allowedMessages: Set<String>?

    // MARK: - Init

    /// Creates a builder backed entirely by bundled resources.
    ///
    /// Uses the schemas shipped with A2UIPrompt (`agent_to_renderer.json`, `common_types.json`)
    /// and the basic catalog shipped with A2UICatalog. Nothing is pruned, so the prompt
    /// advertises the whole catalog.
    public init() {
        _agentToRendererSchema = nil
        _commonTypesSchema = nil
        _catalogSchema = nil
        allowedComponents = nil
        allowedMessages = nil
    }

    /// Creates a builder from custom schema strings, bypassing the bundled resources.
    ///
    /// Use this to target a different A2UI spec version, or to pin the schemas a test runs
    /// against so bundled-resource changes cannot move the expected prompt.
    public init(
        agentToRendererSchema: String,
        commonTypesSchema: String,
        catalogSchema: String
    ) {
        _agentToRendererSchema = agentToRendererSchema
        _commonTypesSchema = commonTypesSchema
        _catalogSchema = catalogSchema
        allowedComponents = nil
        allowedMessages = nil
    }

    /// Creates a builder with a custom **catalog** schema, keeping the bundled
    /// server-to-client and common-types schemas.
    ///
    /// The usual entry point for an app that ships its own component catalog but still speaks
    /// the standard protocol.
    public init(
        catalogSchema: String,
        allowedComponents: Set<String>? = nil,
        allowedMessages: Set<String>? = nil
    ) {
        _agentToRendererSchema = nil
        _commonTypesSchema = nil
        _catalogSchema = catalogSchema
        self.allowedComponents = allowedComponents
        self.allowedMessages = allowedMessages
    }

    /// Creates a builder where every schema is individually optional.
    ///
    /// Each `nil` field falls back to the bundled resource, which is what lets a derived
    /// builder such as `A2UIPromptCompactBuilder` replace one schema and inherit the rest.
    ///
    /// As in the official `with_pruning`, `common_types` is always narrowed by reachability
    /// from the catalog and the agent-to-renderer schema, whether or not an allowlist is given.
    ///
    /// - Parameters:
    ///   - agentToRendererSchema: Replaces the agent_to_renderer schema; `nil` uses the bundled one.
    ///   - commonTypesSchema: Replaces the common_types schema; `nil` uses the bundled one.
    ///   - catalogSchema: Replaces the catalog schema; `nil` uses the bundled basic catalog.
    ///   - allowedComponents: Narrows the catalog `components`; the equivalent of Python
    ///     `with_pruning(allowed_components:)`.
    ///   - allowedMessages: Narrows the agent_to_renderer `oneOf`; the equivalent of Python
    ///     `with_pruning(allowed_messages:)`.
    public init(
        agentToRendererSchema: String?,
        commonTypesSchema: String?,
        catalogSchema: String?,
        allowedComponents: Set<String>? = nil,
        allowedMessages: Set<String>? = nil
    ) {
        _agentToRendererSchema = agentToRendererSchema
        _commonTypesSchema = commonTypesSchema
        _catalogSchema = catalogSchema
        self.allowedComponents = allowedComponents
        self.allowedMessages = allowedMessages
    }

    // MARK: - Presets

    /// Returns a builder configured for the presenter (content-presentation) subset, following
    /// the official `with_pruning`.
    ///
    /// Narrows the catalog to the nine components in `A2UIExample.presenterComponentNames` and
    /// agent_to_renderer to the three messages in `A2UIExample.presenterMessageNames`. Pair it
    /// with the worked example `A2UIExample.presenterSurface`, which is built from the same
    /// subset; a test pins the two together so the pruned schema can never contradict the
    /// example the model imitates.
    public static func presenter() -> A2UIPromptBuilder {
        A2UIPromptBuilder(
            agentToRendererSchema: nil,
            commonTypesSchema: nil,
            catalogSchema: nil,
            allowedComponents: A2UIExample.presenterComponentNames,
            allowedMessages: A2UIExample.presenterMessageNames
        )
    }

    // MARK: - Bundled resources (public)

    /// Returns the bundled `agent_to_renderer.json`, minified with sorted keys.
    ///
    /// A hook for derived builders that need to post-process the schema before feeding it back
    /// through an initializer. Returns `"{}"` if the resource cannot be read.
    public static func bundledAgentToRendererJSON() -> String {
        loadBundledResource("agent_to_renderer")
    }

    /// Returns the bundled `common_types.json`, minified with sorted keys.
    ///
    /// The hook `A2UIPromptCompactBuilder` uses: it runs the result through
    /// `CommonTypesCompactor` and passes the stripped schema back in. Returns `"{}"` if the
    /// resource cannot be read.
    public static func bundledCommonTypesJSON() -> String {
        loadBundledResource("common_types")
    }

    // MARK: - Public API

    /// Assembles the complete system prompt in the official A2UI format.
    ///
    /// Sections are joined with `\n\n`, in this order:
    ///
    /// 1. `role` — required; the assistant's persona.
    /// 2. `## Workflow Description:` — the workflow rules, default or custom.
    /// 3. `## UI Description:` — optional free-form description of the UI structure.
    /// 4. The JSON schema block — only when `includeSchema` is `true`.
    /// 5. `### Examples:` — only when `examples` is non-`nil`.
    ///
    /// The examples come last, after the schema, so the model reads the shape it must satisfy
    /// before the sample that satisfies it.
    ///
    /// - Parameters:
    ///   - role: The role or persona description the LLM adopts.
    ///   - workflowRules: Custom workflow rules; `nil` uses `A2UIWorkflowRules.default`, which
    ///     expects UI as tagged JSON in the text response rather than through a tool call.
    ///   - uiDescription: Optional description of the UI structure to produce.
    ///   - examples: Optional few-shot block, already marked up by `A2UIExampleFormatter` or
    ///     taken from `A2UIExample`.
    ///   - includeSchema: Whether to append the JSON schema block. Defaults to `true`.
    /// - Returns: The assembled system prompt.
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

    /// Assembles only the schema block portion of the prompt.
    ///
    /// Contains the server-to-client, common-types, and catalog schemas after the official
    /// `with_pruning` pipeline has run — components, then messages, then common-types
    /// reachability, the last of which runs unconditionally — laid out by
    /// `SchemaBlockFormatter`.
    ///
    /// If any of the three schemas fails to parse, pruning is skipped and the schemas are
    /// emitted as given, so an allowlist has no effect on an unparseable schema.
    public func schemaBlock() -> String {
        var catalogString = resolvedCatalogSchema
        var s2cString = resolvedServerToClientSchema
        var commonString = resolvedCommonTypesSchema

        if let catalog = Self.parseJSON(catalogString),
           let s2c = Self.parseJSON(s2cString),
           let common = Self.parseJSON(commonString) {
            let pruned = SchemaPruner.withPruning(
                catalog: catalog,
                agentToRenderer: s2c,
                commonTypes: common,
                allowedComponents: allowedComponents,
                allowedMessages: allowedMessages
            )
            catalogString = Self.serializeJSON(pruned.catalog) ?? catalogString
            s2cString = Self.serializeJSON(pruned.agentToRenderer) ?? s2cString
            commonString = Self.serializeJSON(pruned.commonTypes) ?? commonString
        }

        return SchemaBlockFormatter.format(
            agentToRendererSchema: s2cString,
            commonTypesSchema: commonString,
            catalogSchema: catalogString
        )
    }

    // MARK: - Schema resolution

    private var resolvedServerToClientSchema: String {
        _agentToRendererSchema ?? Self.loadBundledResource("agent_to_renderer")
    }

    private var resolvedCommonTypesSchema: String {
        _commonTypesSchema ?? Self.loadBundledResource("common_types")
    }

    private var resolvedCatalogSchema: String {
        _catalogSchema ?? BasicComponentCatalog.catalogSchemaJSON()
    }

    // MARK: - JSON helpers

    private static func parseJSON(_ string: String) -> StructuredValue? {
        try? JSONParser().parse(string)
    }

    private static func serializeJSON(_ value: StructuredValue) -> String? {
        JSONSerializer(options: .init(sortKeys: true)).string(from: value)
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
        guard let url, let data = try? Data(contentsOf: url) else {
            return "{}"
        }
        if let minified = minifyJSON(data) {
            return minified
        }
        return String(data: data, encoding: .utf8) ?? "{}"
    }

    /// Minifies a bundled JSON resource for embedding in the prompt.
    ///
    /// Sorting the keys makes the output byte-identical across runs, which is what keeps the
    /// prompt-cache hit rate stable. Slashes stay unescaped (the `JSONSerializer` default),
    /// so the schema URLs remain readable.
    private static func minifyJSON(_ data: Data) -> String? {
        guard let value = try? JSONParser().parse(data) else { return nil }
        return JSONSerializer(options: .init(sortKeys: true)).string(from: value)
    }
}

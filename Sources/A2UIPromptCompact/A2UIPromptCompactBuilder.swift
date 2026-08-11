import A2UICatalog
import A2UICore
import A2UIPrompt
import Foundation

/// An **unofficial** prompt builder for apps whose catalog exposes no `functions`.
///
/// Removes the `FunctionCall` type definitions from `common_types.json` before the schema block
/// is assembled. That shortens the prompt and, more importantly, stops the model from emitting
/// a call form the app has no way to honour.
///
/// - Wraps `A2UIPrompt`'s `A2UIPromptBuilder`, substituting the bundled common_types with the
///   version `CommonTypesCompactor` produces.
/// - Reachability pruning of `common_types` then removes the `$defs` that the removal left
///   unreachable.
/// - The public API matches `A2UIPromptBuilder`, so the two are interchangeable at the call site.
///
/// **Caution**: parts of the A2UI specification assume a catalog that carries `functions`. This
/// builder is only correct for a catalog that declares `functions: []`; used with a catalog that
/// does declare functions, the prompt describes types the catalog still expects.
public struct A2UIPromptCompactBuilder: Sendable {

    /// The wrapped `A2UIPromptBuilder`, exposed as an escape hatch.
    ///
    /// Hand it to any API that takes an `A2UIPromptBuilder` directly. It already carries the
    /// compacted common_types and the allowlists passed to this initializer, so a prompt built
    /// through it is identical to one built here.
    public let builder: A2UIPromptBuilder
    private var inner: A2UIPromptBuilder { builder }

    /// The compacted common_types, computed once per process and shared by every instance.
    ///
    /// Compaction re-parses and re-serializes the bundled schema, which is too expensive to
    /// repeat for each builder.
    private static let compactCommonTypes: String =
        CommonTypesCompactor.compact(A2UIPromptBuilder.bundledCommonTypesJSON())

    /// Creates a builder whose common_types has the `FunctionCall` definitions removed.
    ///
    /// - Parameters:
    ///   - catalogSchema: Custom catalog JSON; `nil` uses A2UIPrompt's bundled basic catalog.
    ///     Whatever is passed should declare `functions: []`.
    ///   - allowedComponents: Narrows the catalog `components`, for example `["Text", "Button"]`.
    ///   - allowedMessages: Narrows the agent_to_renderer `oneOf`, for example
    ///     `["CreateSurfaceMessage", "UpdateComponentsMessage"]`.
    public init(
        catalogSchema: String? = nil,
        allowedComponents: Set<String>? = nil,
        allowedMessages: Set<String>? = nil
    ) {
        self.builder = A2UIPromptBuilder(
            agentToRendererSchema: nil,                      // bundled
            commonTypesSchema: Self.compactCommonTypes,     // compacted
            catalogSchema: catalogSchema,                   // caller's, or bundled when nil
            allowedComponents: allowedComponents,
            allowedMessages: allowedMessages
            // Reachability pruning of common_types always runs, per the official with_pruning.
        )
    }

    /// Assembles the system prompt exactly as `A2UIPromptBuilder.buildSystemPrompt` does,
    /// except that its schema block carries the compacted common_types.
    public func buildSystemPrompt(
        role: String,
        workflowRules: String? = nil,
        uiDescription: String? = nil,
        examples: String? = nil,
        includeSchema: Bool = true
    ) -> String {
        inner.buildSystemPrompt(
            role: role,
            workflowRules: workflowRules,
            uiDescription: uiDescription,
            examples: examples,
            includeSchema: includeSchema
        )
    }

    /// Returns the schema block alone, with `FunctionCall` already removed from the common types.
    ///
    /// Use it when the prompt is assembled elsewhere and only the schema section comes from here.
    public func schemaBlock() -> String {
        inner.schemaBlock()
    }
}

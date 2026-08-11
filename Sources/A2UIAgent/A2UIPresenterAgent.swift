import A2ACore
import A2UIA2A
import A2UIAgentTool
import A2UICatalog
import A2UICore
import A2UIPrompt
import A2UITyped
import Foundation
import LLMClient
import LLMTool

/// Everything a presenter-style (content-presenting) A2UI agent says about itself.
///
/// This package is the single source of truth for the A2UI domain: the role (system prompt), the
/// tools, the protocol declaration (agent extension) and the delegation blurb (description). A
/// host app only injects them into its executor and makes the domain choices — language, model.
///
/// All UI knowledge, catalog and worked examples included, stays inside this agent. Generation
/// goes through the single `send_a2ui_json_to_client` tool; as in the upstream rizzcharts
/// reference agent, the tool owns the schema and the examples and carries them into the system
/// prompt when it is attached.
public enum A2UIPresenterAgent {
    public static let defaultName = "a2ui"

    /// The presenter's default component palette: the nine content-presentation components.
    /// A host can change the palette by passing any subset to `tools(components:)`.
    public static let defaultComponents = A2UIExample.presenterComponentNames

    /// Normalizes a requested component set against the basic catalog: names the catalog does not
    /// know are dropped, and an empty result falls back to the default palette.
    /// A persisted setting can therefore be passed straight through even when it still holds
    /// names from an older catalog.
    public static func sanitizedComponents(_ requested: Set<String>) -> Set<String> {
        let known = requested.intersection(BasicComponent.componentNames)
        return known.isEmpty ? defaultComponents : known
    }

    /// The worked-example surface to ship with a component set. The rule is that the example must
    /// never contradict the schema:
    /// - the full catalog → `referenceSurface`, which teaches the whole palette
    /// - a superset of the presenter palette → the presentation-focused `presenterSurface`
    /// - anything narrower → no example, because a contradictory example is worse than none;
    ///   generation then runs on the pruned schema block alone
    public static func exampleSurface(for components: Set<String>) -> String? {
        if components == BasicComponent.componentNames {
            return A2UIExample.referenceSurface()
        }
        if A2UIExample.presenterComponentNames.isSubset(of: components) {
            return A2UIExample.presenterSurface()
        }
        return nil
    }

    /// The description an orchestrator reads when deciding whether to delegate (agent card and
    /// routing). It states at card level that the caller passes the complete content and that the
    /// surface keeps being updated every turn, so the agent is not read as a one-shot final step.
    public static let defaultDescription =
        "Renders content as an interactive A2UI surface on the user's screen. Send it the complete "
        + "content to display — it cannot see other agents' replies. Once a surface exists, every "
        + "answer must be sent to it again to update the surface."

    /// The presenter's UI contract: surface lifecycle and the quality bar.
    /// It becomes the `## UI Description:` section of `systemPrompt`.
    public static let uiDescription = """
    - The surface root fills the host frame: use a full-width container (e.g. Column with "align":"stretch") \
    as the component with id "root", not a Card. Use Card only for sub-sections inside a surface.
    - Maintain a SINGLE surface for the whole conversation: reuse the same surfaceId every \
    turn and update it in place with updateComponents / updateDataModel. Do not create additional surfaces.
    - Compose the answer as a data-model-driven A2UI surface, matching the richness and quality of the example \
    below: put dynamic values in the data model and reference them with {"path":"/..."} bindings. On the FIRST \
    paint of a surface, send the full component tree and a single updateDataModel at "/". \
    The example is the quality bar and the source of the reusable patterns — reuse them, but choose the structure \
    and components that fit THIS request instead of copying it verbatim.
    - When updating an EXISTING surface, send the smallest change that realizes it: updateDataModel at the \
    narrowest path(s) that changed (e.g. "/problem", "/items"). Send updateComponents ONLY when the visual \
    structure itself changes — never resend an unchanged component tree. Your earlier A2UI messages in this \
    conversation are the current surface state: diff against them, and never blindly overwrite values the user edited.
    - Keep it interactive across turns: when an action event arrives (e.g. a "followup" carrying an "ask"), treat \
    it as the user's next request and respond by updating the surface, refreshing any \
    "next" suggestions to match the new content.
    """

    /// The a2ui worker's system prompt: role, UI contract and workflow rules.
    ///
    /// The pruned schema for the presenter subset and the worked-example surface are owned by the
    /// tool (`SendA2UIToClientTool`) and travel with it when it is attached, so only the
    /// instructions live here.
    public static func systemPrompt(language: String = "Japanese") -> SystemPrompt {
        var role = SystemPrompt {
            PromptComponent.role("You are an A2UI agent. Render the content given to you as A2UI surface(s) on the user's screen.")
            PromptComponent.note("All user-facing text you produce must be written in \(language).")
            PromptComponent.outputConstraint("Your final output MUST be an A2UI UI rendered as JSON messages — never reply with plain prose only.")
        }.render()
        // Closing sentence of the role, verbatim from the upstream rizzcharts agent: it makes
        // tool use a MUST.
        role += "\nYou MUST use the `\(A2UIToolConstants.toolName)` tool with the "
            + "`\(A2UIToolConstants.jsonArgName)` argument set to the A2UI JSON payload to send to the client."
        let instruction = A2UIPromptBuilder.presenter().buildSystemPrompt(
            role: role,
            workflowRules: A2UIWorkflowRules.toolCall + "\n" + A2UIWorkflowRules.scopeRules + "\n"
                + A2UIWorkflowRules.basicCatalogRules + "\n" + A2UIWorkflowRules.textMathRules,
            uiDescription: uiDescription,
            includeSchema: false
        )
        return SystemPrompt(stringLiteral: instruction)
    }

    /// The a2ui worker's tool set — generation goes through `send_a2ui_json_to_client` alone.
    /// The tool owns the pruned schema and the worked-example surface and carries them into the
    /// system prompt when it is attached, as in the upstream rizzcharts reference agent.
    ///
    /// `components` swaps the catalog palette (the nine presenter components by default). The same
    /// set drives both the prompt pruning and the output validation, so a component that was never
    /// shown to the model comes back as a tool error and is self-corrected inside the same loop.
    /// The messages stay the presenter's three (createSurface / updateComponents /
    /// updateDataModel) — the single-surface convention is independent of the palette.
    public static func tools(components: Set<String> = defaultComponents) -> [any Tool] {
        let allowed = sanitizedComponents(components)
        let promptBuilder = A2UIPromptBuilder(
            agentToRendererSchema: nil,
            commonTypesSchema: nil,
            catalogSchema: nil,
            allowedComponents: allowed,
            allowedMessages: A2UIExample.presenterMessageNames
        )
        return [
            SendA2UIToClientTool<BasicCatalog>(
                examples: exampleSurface(for: allowed).map {
                    A2UIExampleFormatter.format(name: "REFERENCE SURFACE EXAMPLE", content: $0)
                },
                promptBuilder: promptBuilder
            )
        ]
    }

    /// The A2UI protocol extension declared on the agent card: which catalogs this agent supports.
    /// Catalog negotiation belongs to the protocol layer and never enters the LLM prompt.
    public static func agentExtension() -> AgentExtension {
        A2UIExtension.agentExtension(supportedCatalogIds: [BasicCatalog.catalogId])
    }

    /// The constraint to append to the host (orchestrator) output instructions so that delegation
    /// to a2ui is mandatory. Wherever an a2ui worker is in the line-up, every turn has to go
    /// through it: no discretion is left for answering in plain text.
    public static func hostOutputConstraint(agentName: String = defaultName) -> PromptComponent {
        .outputConstraint(
            "Every turn, including follow-ups, must end by sending the complete answer content to the "
                + "`\(agentName)` agent; then reply with one short sentence. Never answer in plain text only.")
    }
}

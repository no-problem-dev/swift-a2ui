import Foundation

/// Wire constants for the two-stage setup: the outer `generate_a2ui` and the inner
/// `render_a2ui`.
///
/// Mirrors `index.ts` in `@ag-ui/a2ui-toolkit`. Tool and argument names are byte-identical to
/// upstream — they form a contract that spans the prompt, the history and the envelope, so any
/// spelling drift becomes an interoperability break.
public enum A2UISubagentConstants {
    /// Name of the outer tool, the one the main planner sees and calls.
    public static let generateToolName = "generate_a2ui"
    /// Name of the inner tool the sub-agent is forced onto via `toolChoice`.
    public static let renderToolName = "render_a2ui"
    /// Key holding the operations array in the tool-result envelope; the same key AG-UI
    /// activity content uses, so the two stay decodable by each other.
    public static let operationsKey = "a2ui_operations"
    /// Prefix every issued surface ID carries. The full ID comes from `newSurfaceId()`.
    public static let surfaceIdPrefix = "surface"
    /// Code embedded in the tool-error text once the retry budget is spent, so a caller can
    /// tell "gave up after retries" from any other failure.
    public static let recoveryExhaustedCode = "a2ui_recovery_exhausted"

    /// Issues the surface ID for this turn.
    ///
    /// The spec requires `surfaceId` to be unique for the renderer's lifetime — recreating an
    /// existing ID without deleting it first is an error. Append-only rendering starts a new
    /// surface every turn, so the host mints a UUID instead of letting the model pick one.
    public static func newSurfaceId() -> String {
        "\(surfaceIdPrefix)-\(UUID().uuidString.lowercased())"
    }

    /// Description of the outer tool, as shown to the main planner.
    ///
    /// There is no update path — rendering is append-only. Wording that hints at rewriting a
    /// past surface makes the model attempt exactly that, so this only ever describes drawing
    /// a new one.
    public static let generateToolDescription =
        "Render a new dynamic A2UI surface based on the conversation. "
            + "A secondary LLM designs the UI components and data. "
            + "Use when the user requests visual content "
            + "(cards, forms, lists, dashboards, comparisons, etc.). "
            + "Each call renders a NEW surface appended to the conversation; previously "
            + "rendered surfaces are never modified. To show revised content, render a new "
            + "surface carrying the updated information."

    /// Per-argument text for the outer tool's JSON Schema, kept here so the planner-facing
    /// wording lives next to the tool description it has to agree with.
    public enum GenerateArgDescriptions {
        public static let intent =
            "Optional natural-language description of what to render "
                + "(e.g. 'a comparison of the three recipes we found')."
    }
}

/// Formats few-shot examples for the system prompt — the Swift counterpart of the official
/// Python `A2uiCatalog.load_examples()` marker format. Workflow prompts reference examples by
/// these markers (e.g. "Use the JSON from `---BEGIN chart---`").
public enum A2UIExampleFormatter {

    /// Wrap one example in `---BEGIN {name}---` / `---END {name}---` markers.
    public static func format(name: String, content: String) -> String {
        "---BEGIN \(name)---\n\(content)\n---END \(name)---"
    }

    /// Merge multiple named examples, separated by blank lines (Python joins with `\n\n`).
    public static func merge(_ examples: [(name: String, content: String)]) -> String {
        examples.map { format(name: $0.name, content: $0.content) }.joined(separator: "\n\n")
    }
}

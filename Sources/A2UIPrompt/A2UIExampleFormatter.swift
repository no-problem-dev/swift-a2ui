/// Marks up few-shot examples in the form the system prompt refers to them by.
///
/// The Swift counterpart of the marker format the official Python `A2uiCatalog.load_examples()`
/// produces. A workflow prompt cites an example by its marker — "Use the JSON from
/// `---BEGIN chart---`" — so the name passed here is the name the prompt text must use.
public enum A2UIExampleFormatter {

    /// Wraps one example in `---BEGIN {name}---` / `---END {name}---` markers.
    ///
    /// - Parameters:
    ///   - name: The label the prompt cites; it appears verbatim in both markers.
    ///   - content: The example body, placed between the markers unchanged.
    public static func format(name: String, content: String) -> String {
        "---BEGIN \(name)---\n\(content)\n---END \(name)---"
    }

    /// Joins several named examples with a blank line between them, matching the Python `\n\n`.
    public static func merge(_ examples: [(name: String, content: String)]) -> String {
        examples.map { format(name: $0.name, content: $0.content) }.joined(separator: "\n\n")
    }
}

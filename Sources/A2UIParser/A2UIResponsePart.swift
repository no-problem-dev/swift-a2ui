import A2UICore

/// One slice of an LLM response — plain text, or agent messages decoded from an
/// `<a2ui-json>` block.
///
/// The parsers emit a new part every time the output crosses a tag boundary, so a sequence of
/// parts preserves the order text and UI arrived in. Each parser-produced part carries one side
/// or the other, never both.
public struct A2UIResponsePart: Sendable, Equatable {
    /// Text that fell outside any `<a2ui-json>` block, trimmed; `nil` on a message part.
    public let text: String?
    /// Messages decoded from one `<a2ui-json>` block; `nil` on a text part.
    ///
    /// A block whose JSON never decodes produces no part at all rather than an empty array, so
    /// an empty result means "nothing decoded", not "a block held no messages".
    public let messages: [AgentMessage]?

    public init(text: String? = nil, messages: [AgentMessage]? = nil) {
        self.text = text
        self.messages = messages
    }

    /// Wraps plain text as a part, leaving `messages` `nil`.
    public static func text(_ text: String) -> A2UIResponsePart {
        A2UIResponsePart(text: text)
    }

    /// Wraps decoded messages as a part, leaving `text` `nil`.
    public static func messages(_ messages: [AgentMessage]) -> A2UIResponsePart {
        A2UIResponsePart(messages: messages)
    }
}

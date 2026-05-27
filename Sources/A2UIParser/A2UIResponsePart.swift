import A2UICore

/// A part of an LLM response — either plain text or decoded A2UI server messages.
public struct A2UIResponsePart: Sendable, Equatable {
    /// Plain text content outside of `<a2ui-json>` blocks.
    public let text: String?
    /// Decoded `ServerMessage` values extracted from a `<a2ui-json>` block.
    public let messages: [ServerMessage]?

    public init(text: String? = nil, messages: [ServerMessage]? = nil) {
        self.text = text
        self.messages = messages
    }

    /// Creates a text-only response part.
    public static func text(_ text: String) -> A2UIResponsePart {
        A2UIResponsePart(text: text)
    }

    /// Creates a messages-only response part.
    public static func messages(_ messages: [ServerMessage]) -> A2UIResponsePart {
        A2UIResponsePart(messages: messages)
    }
}

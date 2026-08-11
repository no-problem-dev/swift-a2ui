import A2UICore

/// One slice of an LLM response — plain text, agent messages decoded from an `<a2ui-json>` block,
/// or a block that carried A2UI and could not be read.
///
/// The parsers emit a new part every time the output crosses a tag boundary, so a sequence of parts
/// preserves the order text and UI arrived in.
///
/// `malformed` exists because "no messages" answers two opposite questions at once. A model that
/// wrote no UI and a model that wrote UI this side cannot parse call for different responses — show
/// the prose, versus tell someone the surface is missing — and only the second is a bug worth
/// chasing. A part that vanished silently could never be told from one that was never sent.
public enum A2UIResponsePart: Sendable, Equatable {
    /// Text that fell outside any `<a2ui-json>` block, trimmed.
    case text(String)
    /// Messages decoded from one `<a2ui-json>` block.
    case messages([AgentMessage])
    /// A block that could not be read in full, carrying its raw content so a caller can log it or
    /// hand it back to the model. A block that decoded only partly emits a `messages` part *and*
    /// this one, so neither the salvage nor the loss goes unrecorded.
    case malformed(A2UIMalformedBlock)
}

/// An `<a2ui-json>` block whose content did not survive decoding intact.
public struct A2UIMalformedBlock: Sendable, Equatable {
    /// The raw text between the tags, exactly as the model wrote it.
    public let raw: String
    /// How many messages inside the block were skipped to salvage the rest; `0` when the whole
    /// block failed to decode.
    public let skipped: Int

    public init(raw: String, skipped: Int = 0) {
        self.raw = raw
        self.skipped = skipped
    }
}

extension A2UIResponsePart {
    /// The text this part carries, or `nil` on any other kind of part.
    public var text: String? {
        if case .text(let text) = self { return text }
        return nil
    }

    /// The messages this part carries, or `nil` on any other kind of part.
    public var messages: [AgentMessage]? {
        if case .messages(let messages) = self { return messages }
        return nil
    }

    /// The unreadable block this part carries, or `nil` on any other kind of part.
    public var malformed: A2UIMalformedBlock? {
        if case .malformed(let block) = self { return block }
        return nil
    }
}

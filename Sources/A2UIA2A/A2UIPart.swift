import A2ACore
import A2UICore

/// A2UI content coding for A2A `Part` values — mirrors the Python SDK's `a2ui/a2a/parts.py`.
///
/// A2UI messages travel as data parts tagged `application/a2ui+json`. swift-a2a implements the
/// A2A v1.0 data model, in which `Part` has a first-class `mediaType`; that is the primary tag.
/// The official v0.x SDK follows the earlier spec and tags parts through `metadata["mimeType"]`,
/// so decoding accepts that position too. Encoding only ever writes `mediaType`.
public enum A2UIMediaType {
    /// Media type every A2UI part is tagged with; the official `A2UI_MIME_TYPE`.
    public static let a2uiJSON = "application/a2ui+json"
    /// Part-metadata key the v0.x Python SDK tags with; the official `MIME_TYPE_KEY`. Accepted on
    /// decode for interoperability, never written.
    public static let metadataKey = "mimeType"
}

extension Part {
    /// Wraps a server-to-client A2UI message as a data part — mirrors `create_a2ui_part`.
    public static func a2ui(_ message: AgentMessage) throws -> Part {
        .data(try .encoded(message), mediaType: A2UIMediaType.a2uiJSON)
    }

    /// Wraps a client-to-server A2UI message — a `userAction`, `functionResponse` or `error` —
    /// as a data part.
    public static func a2ui(_ message: RendererMessage) throws -> Part {
        .data(try .encoded(message), mediaType: A2UIMediaType.a2uiJSON)
    }

    /// `true` when this is a data part tagged as A2UI, by `mediaType` or by the v0.x metadata key
    /// — mirrors `is_a2ui_part`. The tag is all that is checked; the payload may still be junk.
    public var isA2UI: Bool {
        guard case .data = content else { return false }
        if mediaType == A2UIMediaType.a2uiJSON { return true }
        return metadata?[A2UIMediaType.metadataKey]?.stringValue == A2UIMediaType.a2uiJSON
    }

    /// Decodes the server message carried by an A2UI part, returning `nil` when the part is not
    /// A2UI at all. Throws only when the part claims A2UI and its payload will not decode, which
    /// is the one case worth surfacing to the operator.
    public func a2uiAgentMessage() throws -> AgentMessage? {
        guard isA2UI, let value = data else { return nil }
        return try value.decode(AgentMessage.self)
    }

    /// Decodes the client message carried by an A2UI part, returning `nil` when the part is not
    /// A2UI. Throws when the part claims A2UI and its payload will not decode.
    public func a2uiRendererMessage() throws -> RendererMessage? {
        guard isA2UI, let value = data else { return nil }
        return try value.decode(RendererMessage.self)
    }

    /// The part's `userAction` if it carries one, and `nil` when the payload cannot be read.
    ///
    /// Routing treats an unreadable action as absent rather than failing the turn, and falls back
    /// to LLM routing. Use `a2uiRendererMessage()` where the decode error itself matters.
    public var a2uiUserAction: UserAction? {
        guard case .action(let action)? = try? a2uiRendererMessage() else { return nil }
        return action
    }
}

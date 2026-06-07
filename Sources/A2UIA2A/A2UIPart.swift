import A2ACore
import A2UICore

/// A2UI content coding over A2A `Part` (mirror of the Python SDK's `a2ui/a2a/parts.py`).
///
/// A2UI messages travel as data parts tagged `application/a2ui+json`. swift-a2a implements
/// the A2A v1.0 data model, where `Part` carries a first-class `mediaType` — that is the
/// primary tag here. The official v0.x SDK predates it and tags via part
/// `metadata["mimeType"]`; decoding accepts that location too for interop.
public enum A2UIMediaType {
    /// Official `A2UI_MIME_TYPE`.
    public static let a2uiJSON = "application/a2ui+json"
    /// Official `MIME_TYPE_KEY` (part-metadata tag location used by the v0.x Python SDK).
    public static let metadataKey = "mimeType"
}

extension Part {
    /// Wraps a server → client A2UI message (mirror of `create_a2ui_part`).
    public static func a2ui(_ message: ServerMessage) throws -> Part {
        .data(try .encoding(message), mediaType: A2UIMediaType.a2uiJSON)
    }

    /// Wraps a client → server A2UI message (userAction / functionResponse / error).
    public static func a2ui(_ message: ClientMessage) throws -> Part {
        .data(try .encoding(message), mediaType: A2UIMediaType.a2uiJSON)
    }

    /// Whether this part carries A2UI content (mirror of `is_a2ui_part`).
    public var isA2UI: Bool {
        guard case .data = content else { return false }
        if mediaType == A2UIMediaType.a2uiJSON { return true }
        return metadata?[A2UIMediaType.metadataKey]?.stringValue == A2UIMediaType.a2uiJSON
    }

    /// Decodes the A2UI server message, `nil` if this is not an A2UI part.
    /// Throws only when the part claims to be A2UI but the payload is malformed.
    public func a2uiServerMessage() throws -> ServerMessage? {
        guard isA2UI, let value = data else { return nil }
        return try value.decode(ServerMessage.self)
    }

    /// Decodes the A2UI client message, `nil` if this is not an A2UI part.
    public func a2uiClientMessage() throws -> ClientMessage? {
        guard isA2UI, let value = data else { return nil }
        return try value.decode(ClientMessage.self)
    }

    /// The userAction in this part, if any. Malformed payloads read as `nil` — for routing,
    /// an unreadable action should fall back to LLM routing rather than fail the turn.
    public var a2uiUserAction: UserAction? {
        guard case .action(let action)? = try? a2uiClientMessage() else { return nil }
        return action
    }
}

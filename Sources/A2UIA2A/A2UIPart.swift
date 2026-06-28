import A2ACore
import A2UICore

/// A2A の `Part` に対する A2UI コンテンツコーディング（Python SDK の `a2ui/a2a/parts.py` のミラー）。
///
/// A2UI メッセージは `application/a2ui+json` タグ付きのデータパーツで伝達される。swift-a2a は
/// A2A v1.0 データモデルを実装し、`Part` はファーストクラスの `mediaType` を持つ — これが主要タグ。
/// 公式 v0.x SDK はそれ以前の仕様でパート `metadata["mimeType"]` でタグ付けするため、
/// 相互運用のためにデコード時はその位置も受け入れる。
public enum A2UIMediaType {
    /// 公式 `A2UI_MIME_TYPE`。
    public static let a2uiJSON = "application/a2ui+json"
    /// 公式 `MIME_TYPE_KEY`（v0.x Python SDK が使用するパートメタデータのタグ位置）。
    public static let metadataKey = "mimeType"
}

extension Part {
    /// サーバ → クライアントの A2UI メッセージをラップする（`create_a2ui_part` のミラー）。
    public static func a2ui(_ message: ServerMessage) throws -> Part {
        .data(try .encoding(message), mediaType: A2UIMediaType.a2uiJSON)
    }

    /// クライアント → サーバの A2UI メッセージ（userAction / functionResponse / error）をラップする。
    public static func a2ui(_ message: ClientMessage) throws -> Part {
        .data(try .encoding(message), mediaType: A2UIMediaType.a2uiJSON)
    }

    /// このパートが A2UI コンテンツを持つか（`is_a2ui_part` のミラー）。
    public var isA2UI: Bool {
        guard case .data = content else { return false }
        if mediaType == A2UIMediaType.a2uiJSON { return true }
        return metadata?[A2UIMediaType.metadataKey]?.stringValue == A2UIMediaType.a2uiJSON
    }

    /// A2UI サーバメッセージをデコードする。A2UI パーツでない場合は `nil`。
    /// パーツが A2UI を主張しているがペイロードが不正な場合にのみスローする。
    public func a2uiServerMessage() throws -> ServerMessage? {
        guard isA2UI, let value = data else { return nil }
        return try value.decode(ServerMessage.self)
    }

    /// A2UI クライアントメッセージをデコードする。A2UI パーツでない場合は `nil`。
    public func a2uiClientMessage() throws -> ClientMessage? {
        guard isA2UI, let value = data else { return nil }
        return try value.decode(ClientMessage.self)
    }

    /// このパートの userAction（あれば）。ペイロードが読み取れない場合は `nil` —
    /// ルーティングでは、読み取れないアクションはターンを失敗させず LLM ルーティングにフォールバックする。
    public var a2uiUserAction: UserAction? {
        guard case .action(let action)? = try? a2uiClientMessage() else { return nil }
        return action
    }
}

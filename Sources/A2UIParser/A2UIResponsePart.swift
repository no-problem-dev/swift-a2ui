import A2UICore

/// LLM レスポンスの一部 — プレーンテキストまたはデコード済み A2UI サーバメッセージ。
public struct A2UIResponsePart: Sendable, Equatable {
    /// `<a2ui-json>` ブロック外のプレーンテキストコンテンツ。
    public let text: String?
    /// `<a2ui-json>` ブロックから抽出したデコード済み `ServerMessage` の配列。
    public let messages: [ServerMessage]?

    public init(text: String? = nil, messages: [ServerMessage]? = nil) {
        self.text = text
        self.messages = messages
    }

    /// テキストのみのレスポンスパーツを生成する。
    public static func text(_ text: String) -> A2UIResponsePart {
        A2UIResponsePart(text: text)
    }

    /// メッセージのみのレスポンスパーツを生成する。
    public static func messages(_ messages: [ServerMessage]) -> A2UIResponsePart {
        A2UIResponsePart(messages: messages)
    }
}

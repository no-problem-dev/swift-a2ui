import A2UICore

/// LLM レスポンスの一部 — プレーンテキストまたはデコード済み A2UI サーバメッセージ。
public struct A2UIResponsePart: Sendable, Equatable {
    /// `<a2ui-json>` ブロック外のプレーンテキストコンテンツ。
    public let text: String?
    /// `<a2ui-json>` ブロックから抽出したデコード済み `AgentMessage` の配列。
    public let messages: [AgentMessage]?

    public init(text: String? = nil, messages: [AgentMessage]? = nil) {
        self.text = text
        self.messages = messages
    }

    /// テキストのみのレスポンスパーツを生成する。
    public static func text(_ text: String) -> A2UIResponsePart {
        A2UIResponsePart(text: text)
    }

    /// メッセージのみのレスポンスパーツを生成する。
    public static func messages(_ messages: [AgentMessage]) -> A2UIResponsePart {
        A2UIResponsePart(messages: messages)
    }
}

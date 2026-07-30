import A2UICore
import AGUICore
import Foundation

/// ユーザーアクションの復路(クライアント → サーバー)。
///
/// 公式 a2ui-middleware の契約: アクションは frontend tool ではなく
/// `RunAgentInput.forwardedProps.a2uiAction.userAction` で運び、サーバー側が
/// `log_a2ui_event` の合成メッセージペアとして会話履歴に固定する。
public enum A2UIAGUIAction {
    /// クライアント側: forwardedProps に a2uiAction を積む。
    ///
    /// A2UI 仕様は `name` だが、`actionName` を期待するバックエンド実装が
    /// 実在するため両方を積む(公式 Kotlin クライアントと同じ防御)。
    public static func forwardedProps(
        _ action: UserAction,
        merging base: StructuredValue = .object(OrderedObject())
    ) throws -> StructuredValue {
        guard var actionObject = (try StructuredValue.encoded(action)).objectValue else {
            throw AGUIError("UserAction did not encode to an object")
        }
        actionObject["actionName"] = .string(action.name)
        var root = base.objectValue ?? OrderedObject()
        root["a2uiAction"] = .object(["userAction": .object(actionObject)])
        return .object(root)
    }

    /// サーバー側: forwardedProps から userAction を取り出す(無ければ nil)。
    public static func userAction(in forwardedProps: StructuredValue) throws -> UserAction? {
        guard let value = forwardedProps.objectValue?["a2uiAction"]?.objectValue?["userAction"] else {
            return nil
        }
        return try value.decode(UserAction.self)
    }

    /// サーバー側: アクションを会話履歴に固定する合成メッセージペア。
    ///
    /// 1. assistant メッセージ(`log_a2ui_event` の tool call、引数 = userAction の JSON)
    /// 2. tool メッセージ(人間可読の 1 行 —
    ///    `User performed action "<name>" on surface "<surfaceId>" (component: <id>). Context: <JSON>`)
    public static func syntheticMessages(
        for action: UserAction,
        assistantMessageId: String = UUID().uuidString,
        toolCallId: String = UUID().uuidString,
        toolMessageId: String = UUID().uuidString
    ) throws -> [AGUIMessage] {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        let arguments = String(decoding: try encoder.encode(action), as: UTF8.self)
        let contextJSON = String(
            decoding: try encoder.encode(StructuredValue.object(OrderedObject(action.context))),
            as: UTF8.self
        )
        return [
            .assistant(AssistantMessage(
                id: assistantMessageId,
                content: "",
                toolCalls: [
                    AGUIToolCall(
                        id: toolCallId,
                        function: AGUIFunctionCall(
                            name: A2UIAGUIConstants.logActionToolName,
                            arguments: arguments
                        )
                    ),
                ]
            )),
            .tool(ToolMessage(
                id: toolMessageId,
                content: "User performed action \"\(action.name)\" on surface \"\(action.surfaceId)\" "
                    + "(component: \(action.sourceComponentId)). Context: \(contextJSON)",
                toolCallId: toolCallId
            )),
        ]
    }
}

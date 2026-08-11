import StructuredDataCore
import A2UICore
import AGUICore
import Foundation

/// The return path for user actions (client → server).
///
/// Per the upstream a2ui-middleware contract, an action travels in
/// `RunAgentInput.forwardedProps.a2uiAction.userAction` rather than as a frontend tool, and the
/// server pins it into the conversation history as a synthetic `log_a2ui_event` message pair.
public enum A2UIAGUIAction {
    /// Client side: puts a2uiAction into forwardedProps.
    ///
    /// - Parameter duplicatingActionName: Whether to also write `name` into `actionName`.
    ///   **Defaults to `true`**: the A2UI spec says `name`, but backend implementations that
    ///   expect `actionName` exist in the wild, and the upstream Kotlin client guards against
    ///   them the same way.
    ///
    ///   Pass `false` when you own the other end and know it reads only `name`. The field is
    ///   outside the spec, so dropping it stays closer to A2UI's shape.
    public static func forwardedProps(
        _ action: UserAction,
        merging base: StructuredValue = .object(OrderedObject()),
        duplicatingActionName: Bool = true
    ) throws -> StructuredValue {
        guard var actionObject = (try StructuredValue.encoded(action)).objectValue else {
            throw AGUIError("UserAction did not encode to an object")
        }
        if duplicatingActionName {
            actionObject["actionName"] = .string(action.name)
        }
        var root = base.objectValue ?? OrderedObject()
        root["a2uiAction"] = .object(["userAction": .object(actionObject)])
        return .object(root)
    }

    /// Server side: pulls the userAction out of forwardedProps, or `nil` when the props carry
    /// no A2UI action.
    public static func userAction(in forwardedProps: StructuredValue) throws -> UserAction? {
        guard let value = forwardedProps.objectValue?["a2uiAction"]?.objectValue?["userAction"] else {
            return nil
        }
        return try value.decode(UserAction.self)
    }

    /// Server side: the synthetic message pair that pins an action into the conversation history.
    ///
    /// 1. An assistant message: a `log_a2ui_event` tool call whose arguments are the userAction as JSON.
    /// 2. A tool message: one human-readable line —
    ///    `User performed action "<name>" on surface "<surfaceId>" (component: <id>). Context: <JSON>`
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

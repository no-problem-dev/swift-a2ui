import JSONParsing
import A2UICore
import A2UIParser
import Foundation
import LLMClient
import LLMTool
import StructuredDataCore

/// The inner tool the sub-agent is forced to call — `render_a2ui`.
///
/// Mirrors `RENDER_A2UI_TOOL_DEF` in `@ag-ui/a2ui-toolkit` (typed) and the Gemini-facing
/// declaration in `ag_ui_adk.a2ui_tool` (freeform).
///
/// Bind this as the sub-agent's **only** tool and name it in `toolChoice: .tool(name)`.
/// Answering with text stops being an option at the provider API level, which is what makes
/// the "wrote the A2UI JSON into the message body" failure mode impossible rather than rare.
///
/// `catalogId` is deliberately **not** an argument: the catalog belongs to the host, and the
/// sub-agent must not be able to name one that was never registered.
///
/// The catalog definition lives in the sub-agent's **prompt** (`## Available Components`),
/// not in this schema. Structural checking is `A2UIValidation`'s job.
public struct RenderA2UITool: Tool {
    /// How the payload arguments are declared. Choose by how strictly the provider fills
    /// function-call arguments.
    public enum PayloadShape: Sendable, Equatable {
        /// Declares `components` as `array<object>` and `data` as `object`, the shared
        /// upstream definition. LangGraph and OpenAI-style providers fill these from the
        /// prompt text even though the schema itself is loose.
        case typed
        /// Declares `components` and `data` as **JSON strings** — the glue for ADK/Gemini.
        ///
        /// Gemini's function calling fills typed arguments **strictly**: an `array<object>`
        /// with no declared properties comes back as an empty `{}`, and a field that was not
        /// declared is never emitted at all (observed as `Key 'component' not found`, then
        /// `Key 'children'/'text' not found` once a skeleton was declared). Taking a string
        /// lets the model write A2UI JSON freely against the catalog in its prompt, and this
        /// side parses it back.
        case freeform
    }

    /// Name the sub-agent is forced onto; defaults to the upstream `render_a2ui`.
    public let toolName: String
    /// Declaration shape in use. Switch to `.freeform` for providers that fill typed
    /// arguments strictly enough to hollow out an untyped `array<object>`.
    public let payloadShape: PayloadShape

    public init(
        toolName: String = A2UISubagentConstants.renderToolName,
        payloadShape: PayloadShape = .typed
    ) {
        self.toolName = toolName
        self.payloadShape = payloadShape
    }

    public var toolDescription: String {
        "Render a dynamic A2UI surface. The root component must have id 'root'. "
            + "Use components from the available catalog only."
    }

    public var inputSchema: JSONSchema {
        switch payloadShape {
        case .typed:
            .object(
                properties: [
                    "surfaceId": .string(description: "Unique surface identifier."),
                    "components": .array(
                        description: "A2UI component array (flat format). The root component must have id 'root'.",
                        items: .object(properties: [:], additionalProperties: true)
                    ),
                    "data": .object(
                        description: "Optional initial data model for the surface (form values, list items, etc.).",
                        properties: [:],
                        additionalProperties: true
                    ),
                ],
                required: ["surfaceId", "components"]
            )
        case .freeform:
            .object(
                properties: [
                    "surfaceId": .string(description: "Unique surface identifier."),
                    "components": .string(
                        description: "The A2UI component array as a JSON string, e.g."
                            + #" '[{"id":"root","component":"Text","text":"Hi"}]'."#
                            + " The root component must have id 'root'."
                    ),
                    "data": .string(
                        description: "Optional surface data model as a JSON string, e.g."
                            + #" '{"items":[...]}'. Use '{}' when there is none."#
                    ),
                ],
                required: ["surfaceId", "components"]
            )
        }
    }

    /// Never runs in the sub-agent flow, and always returns `{}` if it somehow does.
    ///
    /// The caller reads the tool call's arguments directly (see `A2UISubagentRunner`); this
    /// body exists only so the type satisfies `Tool` and can be registered in a tool set.
    public func execute(with argumentsData: Data) async throws -> ToolResult {
        .text("{}")
    }
}

/// The `render_a2ui` arguments a sub-agent returned, narrowed from untrusted model output.
public struct RenderA2UIArguments: Sendable, Equatable {
    public let surfaceId: String
    public let components: [StructuredValue]
    public let data: StructuredValue?

    public init(surfaceId: String, components: [StructuredValue], data: StructuredValue?) {
        self.surfaceId = surfaceId
        self.components = components
        self.data = data
    }

    /// Reads the raw JSON arguments of a tool call.
    ///
    /// `components` and `data` are accepted **either structured or as a JSON string**, so one
    /// initializer covers both the `.typed` and `.freeform` declarations. A string is repaired
    /// through `JSONSanitizer` before parsing — Gemini's free-form JSON routinely carries
    /// smart quotes, code fences and trailing commas.
    ///
    /// What cannot be recovered is treated as absent: `nil` when `components` is unusable, and
    /// no data model when only `data` is. Nothing broken is committed — the validator rejects
    /// the attempt and the retry loop takes it from there.
    public init?(argumentsData: Data) {
        guard let root = try? JSONParser().parse(argumentsData) else { return nil }
        let surfaceId = root["surfaceId"].stringValue ?? ""

        guard let components = Self.array(from: root["components"]) else { return nil }
        self.init(
            surfaceId: surfaceId,
            components: components,
            data: Self.object(from: root["data"])
        )
    }

    /// Reads an array, or a JSON string spelling one, as an array.
    private static func array(from value: StructuredValue) -> [StructuredValue]? {
        if let array = value.arrayValue {
            return array
        }
        guard let json = value.stringValue else { return nil }
        let sanitized = JSONSanitizer.sanitize(json)
        guard !sanitized.isEmpty, let parsed = try? JSONParser().parse(Data(sanitized.utf8)) else {
            return nil
        }
        if let array = parsed.arrayValue {
            return array
        }
        // Wrap a lone object into an array — the same leniency as upstream parse_and_fix.
        if case .object = parsed {
            return [parsed]
        }
        return nil
    }

    /// Reads an object, or a JSON string spelling one, as an object.
    /// Anything invalid as a data model — array, null, scalar, or an empty `{}` — gives `nil`.
    private static func object(from value: StructuredValue) -> StructuredValue? {
        if case .object(let fields) = value {
            return fields.isEmpty ? nil : value
        }
        guard let json = value.stringValue else { return nil }
        let sanitized = JSONSanitizer.sanitize(json)
        guard !sanitized.isEmpty,
              let parsed = try? JSONParser().parse(Data(sanitized.utf8)),
              case .object(let fields) = parsed,
              !fields.isEmpty else {
            return nil
        }
        return parsed
    }
}

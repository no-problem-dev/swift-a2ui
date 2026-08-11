import A2UICore
import Foundation
import LLMClient
import LLMTool
import StructuredDataCore

/// The outer tool the main planner calls — `generate_a2ui`.
///
/// Mirrors `generate_a2ui` in `@ag-ui/a2ui-toolkit`.
///
/// Its only argument is `intent`, and it carries **no A2UI JSON**. The main model can express
/// nothing beyond "render some UI"; the JSON comes from the sub-agent, an LLM request forced
/// to call `RenderA2UITool`. That keeps the A2UI schema out of the main system prompt and
/// removes the path by which the JSON leaks into assistant text.
///
/// ## Append-only
///
/// This tool emits **`createSurface` and nothing else**. One turn is one new surface; earlier
/// surfaces are never rewritten, they stack up the way a conversation log does. In v1.0
/// `createSurface` can carry `components` and `dataModel` together, so a whole screen fits in
/// a single message.
///
/// Neither A2UI nor AG-UI has a way to negotiate "only these operations are allowed", so — as
/// upstream does — the restriction is carried by the **shape of the tool**: the `render_a2ui`
/// arguments handed to the sub-agent have no operation discriminator, and this tool only ever
/// builds `createSurface`, leaving update and delete inexpressible. A use case that keeps
/// updating one canvas needs a separate tool.
///
/// `catalogId` and `surfaceId` belong to the host; the model does not choose them. `surfaceId`
/// especially must be unique for the renderer's lifetime under the spec (recreating an
/// existing id is an error), and model-chosen ids collide, so the host issues a fresh one
/// every turn.
public struct GenerateA2UITool: TurnEndingTool, TranscriptAwareTool {
    /// Host-supplied way of calling the sub-agent.
    ///
    /// - Parameters:
    ///   - prompt: The assembled system prompt.
    ///   - attempt: One-based attempt number, for logging and observability.
    ///   - transcript: The conversation as of this call, with the in-flight `generate_a2ui`
    ///     call already stripped. Pass it straight into the sub-agent's LLM request — without
    ///     the tool results gathered earlier in the same run (search hits and the like), the
    ///     model invents the data it renders.
    /// - Returns: The `render_a2ui` arguments, or `nil` when no tool call came back.
    public typealias Invoke = @Sendable (
        _ prompt: String,
        _ attempt: Int,
        _ transcript: [LLMMessage]
    ) async throws -> RenderA2UIArguments?

    /// Checks generated messages against the host's catalog and allowlist, returning one
    /// human-readable string per problem and an empty array when the messages are valid.
    /// The strings go straight back into the sub-agent's prompt, so write them for a reader.
    public typealias Validate = @Sendable ([AgentMessage]) -> [String]

    /// Issues the surface ID for this turn; a UUID by default.
    ///
    /// The spec demands uniqueness for the renderer's lifetime, so the host decides rather
    /// than the model. It is injectable so tests can pin a deterministic ID.
    public typealias MakeSurfaceId = @Sendable () -> String

    public let toolName: String
    private let catalogId: String
    private let prompt: A2UISubagentPrompt
    private let runner: A2UISubagentRunner
    private let invoke: Invoke
    private let validate: Validate
    private let makeSurfaceId: MakeSurfaceId

    public init(
        toolName: String = A2UISubagentConstants.generateToolName,
        catalogId: String,
        prompt: A2UISubagentPrompt,
        runner: A2UISubagentRunner = A2UISubagentRunner(),
        invoke: @escaping Invoke,
        validate: @escaping Validate,
        makeSurfaceId: @escaping MakeSurfaceId = { A2UISubagentConstants.newSurfaceId() }
    ) {
        self.toolName = toolName
        self.catalogId = catalogId
        self.prompt = prompt
        self.runner = runner
        self.invoke = invoke
        self.validate = validate
        self.makeSurfaceId = makeSurfaceId
    }

    public var toolDescription: String { A2UISubagentConstants.generateToolDescription }

    /// Because rendering is append-only, no target surface and no diff appear here — all the
    /// model can state is what it wants drawn, and even that is optional.
    public var inputSchema: JSONSchema {
        .object(
            properties: [
                "intent": .string(description: A2UISubagentConstants.GenerateArgDescriptions.intent),
            ],
            required: []
        )
    }

    /// Runs without a transcript, as `Tool` requires.
    ///
    /// A loop runtime that honours `TranscriptAwareTool` never reaches this. Delegating with
    /// an empty transcript leaves the sub-agent with no conversation to ground itself in,
    /// which is exactly the condition under which it invents data.
    public func execute(with argumentsData: Data) async throws -> ToolResult {
        try await execute(with: argumentsData, transcript: [])
    }

    public func execute(with argumentsData: Data, transcript: [LLMMessage]) async throws -> ToolResult {
        // Strip the in-flight generate_a2ui call, the way Strands does it conditionally.
        // A toolUse with no matching result is rejected by the provider, and the sub-agent
        // is not given this tool in the first place.
        let conversation = Self.strippingInFlightCall(from: transcript, toolName: toolName)

        // This turn's surface: always new, never touching an earlier one.
        let surfaceId = makeSurfaceId()

        let result = try await runner.run(
            basePrompt: prompt.render(),
            invoke: { prompt, attempt in try await invoke(prompt, attempt, conversation) },
            buildMessages: { rendered in
                Self.messages(from: rendered, catalogId: catalogId, surfaceId: surfaceId)
            },
            validate: validate
        )

        guard result.ok else {
            let detail = result.attempts.last?.issues.joined(separator: "; ") ?? "unknown"
            return .error(
                "Failed to generate valid A2UI after \(result.attempts.count) attempt(s)"
                    + " [\(A2UISubagentConstants.recoveryExhaustedCode)]: \(detail)"
            )
        }

        // Return under the same key as upstream's `wrapAsOperationsEnvelope`.
        // The raw operations stay in the history as this tool's result.
        return .json(try JSONEncoder().encode(OperationsEnvelope(messages: result.messages)))
    }

    /// Drops the trailing message when it holds this tool's own call, still awaiting a result.
    ///
    /// Mirrors `stripInFlightToolCall` in the Strands adapter. Unlike LangGraph's
    /// unconditional `slice(0, -1)`, it strips only when the last message is from the
    /// assistant *and* contains a toolUse under this tool's name — depending on the loop
    /// structure the tail is not always a tool call, and removing it blindly can throw away a
    /// user turn.
    static func strippingInFlightCall(from transcript: [LLMMessage], toolName: String) -> [LLMMessage] {
        guard let last = transcript.last,
              last.role == .assistant,
              last.toolUses.contains(where: { $0.name == toolName }) else {
            return transcript
        }
        return Array(transcript.dropLast())
    }

    /// Converts `render_a2ui` arguments into A2UI messages.
    ///
    /// Always **exactly one** message: in v1.0 `createSurface` carries `components` and
    /// `dataModel` itself. `updateComponents` and `updateDataModel` are never produced — that
    /// is what append-only amounts to in practice, and the tool's shape is what guarantees it.
    ///
    /// Both `catalogId` and `surfaceId` come from the host; the `surfaceId` in the model's own
    /// output is discarded.
    static func messages(
        from args: RenderA2UIArguments,
        catalogId: String,
        surfaceId: String
    ) -> [AgentMessage] {
        [
            .createSurface(CreateSurface(
                surfaceId: surfaceId,
                catalogId: catalogId,
                components: args.components,
                dataModel: args.data
            )),
        ]
    }

}

/// The envelope shape upstream's `wrapAsOperationsEnvelope` produces.
///
/// Keyed by `A2UISubagentConstants.operationsKey` through an explicit coding key, so that constant
/// is what actually decides the wire key. Spelling it as a Swift property name instead left the
/// constant looking authoritative while changing it did nothing — and the key is a contract shared
/// with AG-UI activity content and `A2UIOperationsExtractor`.
struct OperationsEnvelope: Codable {
    let messages: [AgentMessage]

    private struct Key: CodingKey {
        let stringValue: String
        var intValue: Int? { nil }
        init?(stringValue: String) { self.stringValue = stringValue }
        init?(intValue: Int) { nil }
    }

    private static var operationsKey: Key { Key(stringValue: A2UISubagentConstants.operationsKey)! }

    init(messages: [AgentMessage]) { self.messages = messages }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: Key.self)
        messages = try container.decode([AgentMessage].self, forKey: Self.operationsKey)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: Key.self)
        try container.encode(messages, forKey: Self.operationsKey)
    }
}

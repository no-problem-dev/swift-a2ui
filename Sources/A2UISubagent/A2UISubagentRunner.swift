import A2UICore
import Foundation
import StructuredDataCore

/// Record of one sub-agent attempt, kept even for the successful one so a caller can see how
/// many retries the surface cost.
public struct A2UIAttemptRecord: Sendable, Equatable {
    public let attempt: Int
    public let ok: Bool
    /// Problems the validator found, worded for a human and fed back into the prompt verbatim.
    public let issues: [String]

    public init(attempt: Int, ok: Bool, issues: [String]) {
        self.attempt = attempt
        self.ok = ok
        self.issues = issues
    }
}

/// Outcome of a sub-agent run, covering every attempt it took.
public struct A2UISubagentResult: Sendable, Equatable {
    /// The A2UI messages that passed validation; empty when every attempt failed.
    public let messages: [AgentMessage]
    public let attempts: [A2UIAttemptRecord]
    public var ok: Bool { !messages.isEmpty }

    public init(messages: [AgentMessage], attempts: [A2UIAttemptRecord]) {
        self.messages = messages
        self.attempts = attempts
    }
}

/// Drives the sub-agent with validation-driven retries.
///
/// Mirrors `runA2UIGenerationWithRecovery` in `@ag-ui/a2ui-toolkit`.
///
/// The design rests on three points:
/// - Each attempt **rebuilds the prompt from `basePrompt`**, so fix-it blocks never stack up
/// - An attempt that passed validation is never retried
/// - Exhausting the budget returns an empty result, which the caller reports back to the model
///   as a tool error rather than as silence
public struct A2UISubagentRunner: Sendable {
    /// Retry budget used when the caller does not set one, matching upstream's
    /// `MAX_A2UI_ATTEMPTS`.
    public static let defaultMaxAttempts = 3

    private let maxAttempts: Int

    public init(maxAttempts: Int = A2UISubagentRunner.defaultMaxAttempts) {
        self.maxAttempts = max(1, maxAttempts)
    }

    /// Calls the sub-agent until validation passes, at most `maxAttempts` times.
    ///
    /// - Parameters:
    ///   - basePrompt: The sub-agent's system prompt. Every attempt starts from this exact
    ///     string, with only the current attempt's fix-it block appended.
    ///   - invoke: Takes a prompt and returns the `render_a2ui` arguments, or `nil` when no
    ///     tool call came back — which counts as a failed attempt, not an error.
    ///   - buildMessages: Turns those arguments into A2UI messages; the host owns the
    ///     `catalogId` it stamps in.
    ///   - validate: Checks the messages and returns one human-readable string per problem.
    public func run(
        basePrompt: String,
        invoke: (_ prompt: String, _ attempt: Int) async throws -> RenderA2UIArguments?,
        buildMessages: (RenderA2UIArguments) -> [AgentMessage],
        validate: ([AgentMessage]) -> [String]
    ) async throws -> A2UISubagentResult {
        var attempts: [A2UIAttemptRecord] = []
        var lastIssues: [String] = []

        for attempt in 1 ... maxAttempts {
            let prompt = Self.augment(basePrompt, with: lastIssues)
            guard let args = try await invoke(prompt, attempt) else {
                let issues = ["Sub-agent did not call \(A2UISubagentConstants.renderToolName)"]
                attempts.append(A2UIAttemptRecord(attempt: attempt, ok: false, issues: issues))
                lastIssues = issues
                continue
            }

            let messages = buildMessages(args)
            let issues = validate(messages)
            attempts.append(A2UIAttemptRecord(attempt: attempt, ok: issues.isEmpty, issues: issues))
            if issues.isEmpty {
                return A2UISubagentResult(messages: messages, attempts: attempts)
            }
            lastIssues = issues
        }

        return A2UISubagentResult(messages: [], attempts: attempts)
    }

    /// Appends the validation problems to the base prompt as a fix-it block, and returns the
    /// prompt untouched when there are none.
    static func augment(_ prompt: String, with issues: [String]) -> String {
        guard !issues.isEmpty else { return prompt }
        let formatted = issues.map { "- \($0)" }.joined(separator: "\n")
        return prompt
            + "\n\n## Previous attempt was invalid — fix these and regenerate:\n"
            + formatted
            + "\n"
    }
}

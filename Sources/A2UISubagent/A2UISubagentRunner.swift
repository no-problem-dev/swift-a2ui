import A2UICore
import Foundation
import StructuredDataCore

/// 副エージェント呼び出しの 1 試行の記録。
public struct A2UIAttemptRecord: Sendable, Equatable {
    public let attempt: Int
    public let ok: Bool
    /// 検証で見つかった問題（人間可読・そのままプロンプトに戻す形）。
    public let issues: [String]

    public init(attempt: Int, ok: Bool, issues: [String]) {
        self.attempt = attempt
        self.ok = ok
        self.issues = issues
    }
}

/// リトライ込みの副エージェント実行結果。
public struct A2UISubagentResult: Sendable, Equatable {
    /// 検証を通った A2UI メッセージ列。失敗時は空。
    public let messages: [ServerMessage]
    public let attempts: [A2UIAttemptRecord]
    public var ok: Bool { !messages.isEmpty }

    public init(messages: [ServerMessage], attempts: [A2UIAttemptRecord]) {
        self.messages = messages
        self.attempts = attempts
    }
}

/// 副エージェントを検証リトライ付きで回す。
///
/// ミラー元: `@ag-ui/a2ui-toolkit` の `runA2UIGenerationWithRecovery`。
///
/// 設計上の要点:
/// - プロンプトは**毎回 basePrompt から作り直す**（前回の追記を蓄積しない）
/// - 検証を通った試行は絶対に再試行しない
/// - 打ち切ったら空の結果を返し、呼び出し側がツールエラーとしてモデルへ返す
public struct A2UISubagentRunner: Sendable {
    /// 既定の最大試行回数（公式 `MAX_A2UI_ATTEMPTS`）。
    public static let defaultMaxAttempts = 3

    private let maxAttempts: Int

    public init(maxAttempts: Int = A2UISubagentRunner.defaultMaxAttempts) {
        self.maxAttempts = max(1, maxAttempts)
    }

    /// 副エージェントを呼び、検証を通るまで（最大 `maxAttempts` 回）繰り返す。
    ///
    /// - Parameters:
    ///   - basePrompt: 副エージェントのシステムプロンプト（毎回この文字列を起点にする）。
    ///   - invoke: プロンプトを受けて `render_a2ui` の引数を返すクロージャ。
    ///     ツール呼び出しが得られなければ `nil`。
    ///   - buildMessages: 引数を A2UI メッセージ列に変換するクロージャ（catalogId はホストが決める）。
    ///   - validate: メッセージ列を検証し、問題があれば人間可読な文字列で返すクロージャ。
    public func run(
        basePrompt: String,
        invoke: (_ prompt: String, _ attempt: Int) async throws -> RenderA2UIArguments?,
        buildMessages: (RenderA2UIArguments) -> [ServerMessage],
        validate: ([ServerMessage]) -> [String]
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

    /// 検証エラーを fix-it ブロックとして基底プロンプトに追記する。
    static func augment(_ prompt: String, with issues: [String]) -> String {
        guard !issues.isEmpty else { return prompt }
        let formatted = issues.map { "- \($0)" }.joined(separator: "\n")
        return prompt
            + "\n\n## Previous attempt was invalid — fix these and regenerate:\n"
            + formatted
            + "\n"
    }
}

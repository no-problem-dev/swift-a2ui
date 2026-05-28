import A2UICore

/// Evaluates a component's `checks` (spec §"Client-side logic & validation").
///
/// Each `CheckRule` has a boolean `condition` and a `message`. A check **passes** when its
/// condition resolves to `true`. The first failing check's message is the active validation error.
/// Per spec, a `Button` with failing checks should be disabled.
public enum ChecksEvaluator {

    /// Returns the message of the first failing check, or nil if all checks pass.
    public static func firstFailure(_ checks: [CheckRule], in context: DataContext) -> String? {
        for check in checks where !context.resolveBool(check.condition) {
            return check.message
        }
        return nil
    }

    /// True if every check passes (or there are none).
    public static func allPass(_ checks: [CheckRule], in context: DataContext) -> Bool {
        firstFailure(checks, in: context) == nil
    }
}

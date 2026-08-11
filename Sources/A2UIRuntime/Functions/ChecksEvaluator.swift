import A2UICore

/// Evaluates a component's `checks` (spec §"Client-side logic & validation").
///
/// Each `CheckRule` pairs a boolean `condition` with a `message`: the check passes when the condition
/// resolves to `true`, and the message of the first failing check is the error in effect. Per the spec, a
/// `Button` whose checks fail is to be disabled.
public enum ChecksEvaluator {

    /// Returns the message of the first failing check, or `nil` when they all pass.
    ///
    /// Only the first failure is reported, so order the rules the way the user should be told about
    /// them. A condition bound to a path that has not arrived coerces to `false` and counts as a failure.
    public static func firstFailure(_ checks: [CheckRule], in context: DataContext) -> String? {
        for check in checks where !context.resolveBool(check.condition) {
            return check.message
        }
        return nil
    }

    /// Whether every check passes. An empty `checks` array passes, so an unvalidated input is never
    /// blocked.
    public static func allPass(_ checks: [CheckRule], in context: DataContext) -> Bool {
        firstFailure(checks, in: context) == nil
    }
}

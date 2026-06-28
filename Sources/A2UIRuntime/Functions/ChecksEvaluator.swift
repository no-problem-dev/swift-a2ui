import A2UICore

/// コンポーネントの `checks`（仕様 §"Client-side logic & validation"）を評価する。
///
/// 各 `CheckRule` はブール値の `condition` と `message` を持つ。条件が `true` に解決されると
/// 検証が通過する。最初に失敗した検証のメッセージが有効な検証エラーとなる。
/// 仕様によれば、検証失敗がある `Button` は無効化すべき。
public enum ChecksEvaluator {

    /// 最初に失敗した検証のメッセージを返す。全検証が通過した場合は nil。
    public static func firstFailure(_ checks: [CheckRule], in context: DataContext) -> String? {
        for check in checks where !context.resolveBool(check.condition) {
            return check.message
        }
        return nil
    }

    /// 全検証が通過している（または検証がない）場合は true。
    public static func allPass(_ checks: [CheckRule], in context: DataContext) -> Bool {
        firstFailure(checks, in: context) == nil
    }
}

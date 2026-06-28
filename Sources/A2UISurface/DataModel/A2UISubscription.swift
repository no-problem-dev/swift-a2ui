/// キャンセル可能なサブスクリプションハンドル。
///
/// `renderer_guide.md` §3 の規約に従い、すべてのステートフルサブスクリプションは
/// メモリリークを防ぐため明示的なキャンセル手段を持たなければならない。
/// `cancel()` の呼び出しまたは `deinit` によってリスナーが切り離される。
public final class A2UISubscription {
    private var onCancel: (() -> Void)?

    init(onCancel: @escaping () -> Void) {
        self.onCancel = onCancel
    }

    /// 無効なサブスクリプション（キャンセル対象なし）。
    /// リテラルや静的バインディングのように監視するデータモデルパスが存在しない場合に使う。
    public static var inert: A2UISubscription {
        A2UISubscription(onCancel: {})
    }

    /// リスナーを切り離す。冪等。
    public func cancel() {
        onCancel?()
        onCancel = nil
    }

    deinit {
        onCancel?()
    }
}

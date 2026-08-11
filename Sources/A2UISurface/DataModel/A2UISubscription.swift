/// A cancellable handle for one data model subscription.
///
/// `renderer_guide.md` §3 requires every stateful subscription to expose an explicit way to cancel
/// so listeners cannot leak. Both `cancel()` and `deinit` detach the listener, which means dropping
/// the handle ends the subscription — store it for as long as you want the callback to fire.
public final class A2UISubscription {
    private var onCancel: (() -> Void)?

    init(onCancel: @escaping () -> Void) {
        self.onCancel = onCancel
    }

    /// A handle with nothing attached to cancel.
    ///
    /// Use it where a binding has no data model path to watch — a literal or a static binding — so
    /// callers can hold one handle type either way instead of an optional.
    public static var inert: A2UISubscription {
        A2UISubscription(onCancel: {})
    }

    /// Detaches the listener. Idempotent.
    ///
    /// A notification already in flight is still delivered, so the callback can run one more time
    /// after this returns.
    public func cancel() {
        onCancel?()
        onCancel = nil
    }

    deinit {
        onCancel?()
    }
}

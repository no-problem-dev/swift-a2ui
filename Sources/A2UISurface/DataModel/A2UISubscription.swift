/// A cancellable subscription handle.
///
/// Per `renderer_guide.md` §3, every stateful subscription MUST provide a clear way to
/// unsubscribe to prevent memory leaks. Calling `cancel()` (or deinit) detaches the listener.
public final class A2UISubscription {
    private var onCancel: (() -> Void)?

    init(onCancel: @escaping () -> Void) {
        self.onCancel = onCancel
    }

    /// Detach the listener. Idempotent.
    public func cancel() {
        onCancel?()
        onCancel = nil
    }

    deinit {
        onCancel?()
    }
}

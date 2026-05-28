/// A cancellable subscription handle.
///
/// Per `renderer_guide.md` §3, every stateful subscription MUST provide a clear way to
/// unsubscribe to prevent memory leaks. Calling `cancel()` (or deinit) detaches the listener.
public final class A2UISubscription {
    private var onCancel: (() -> Void)?

    init(onCancel: @escaping () -> Void) {
        self.onCancel = onCancel
    }

    /// An inert subscription (nothing to cancel). Useful for literal/static bindings that have
    /// no underlying data-model path to observe.
    public static var inert: A2UISubscription {
        A2UISubscription(onCancel: {})
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

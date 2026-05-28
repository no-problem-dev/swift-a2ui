import Foundation

/// A minimal multicast event stream with unsubscription (spec §3 "Event Streams").
///
/// Used for discrete lifecycle/action events (`onSurfaceCreated`, `onAction`, `onUpdated`).
/// Listeners are invoked synchronously in registration order. `subscribe` returns an
/// `A2UISubscription` whose `cancel()` (or deinit) detaches the listener.
public final class EventSource<Payload>: @unchecked Sendable {
    private var listeners: [Int: (Payload) -> Void] = [:]
    private var nextToken = 0
    private let lock = NSRecursiveLock()

    public init() {}

    /// Register a listener. Does NOT replay past events (discrete stream semantics).
    @discardableResult
    public func subscribe(_ listener: @escaping (Payload) -> Void) -> A2UISubscription {
        lock.lock()
        let token = nextToken
        nextToken += 1
        listeners[token] = listener
        lock.unlock()
        return A2UISubscription { [weak self] in
            guard let self else { return }
            self.lock.lock()
            self.listeners.removeValue(forKey: token)
            self.lock.unlock()
        }
    }

    /// Emit a payload to all current listeners.
    public func emit(_ payload: Payload) {
        lock.lock()
        let current = Array(listeners.values)
        lock.unlock()
        for listener in current {
            listener(payload)
        }
    }
}

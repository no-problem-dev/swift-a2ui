import StructuredDataCore
import A2UICore
import Foundation

/// A reactive store holding the application data of a single surface.
///
/// Implements the `DataModel` contract of `renderer_guide.md` §3:
/// - JSON Pointer `get` / `set` over absolute and A2UI-relative paths, creating intermediate
///   containers on the way.
/// - `subscribe(path:)` fires once synchronously with the current value, then again on every
///   relevant change. Cancel through `A2UISubscription`.
/// - **Bubble & cascade notification**: a write to `path` notifies the subscribers of `path`
///   itself, of every ancestor (bubble), and of every descendant (cascade). Writing `/user/name`
///   therefore wakes a subscriber on `/user`, and replacing `/user` wholesale wakes a subscriber
///   on `/user/name`.
///
/// A reference type, and deliberately not `@Observable`: SwiftUI never subscribes to it directly.
/// The binder layer converts path subscriptions into `@Observable` `ResolvedProps`.
public final class DataModel: @unchecked Sendable {

    private var root: StructuredValue
    private var listeners: [Int: (path: String, callback: (StructuredValue?) -> Void)] = [:]
    private var nextToken = 0
    private let lock = NSRecursiveLock()

    public init(_ initial: StructuredValue = .object([:])) {
        self.root = initial
    }

    /// The whole model as one value, copied under the lock.
    ///
    /// The copy does not track later writes, so read it again rather than holding on to it.
    public var snapshot: StructuredValue {
        lock.lock(); defer { lock.unlock() }
        return root
    }

    // MARK: - Read

    /// Resolves a path to its current value, accepting both absolute (`/a/b`) and relative (`a/b`)
    /// forms.
    ///
    /// Returns `nil` when the path does not resolve; callers treat that as `undefined`. A path that
    /// is absent and a path whose intermediate node has the wrong type both come back as `nil`.
    public func get(_ path: String, scope: String = "") -> StructuredValue? {
        lock.lock(); defer { lock.unlock() }
        return JSONPointer.resolve(path: path, scope: scope, in: root)
    }

    // MARK: - Write

    /// Writes the value at `path`, or deletes it when `value` is `nil`, then notifies every
    /// affected subscriber.
    ///
    /// - Passing `nil` follows the spec's Undefined Handling rules: the object key is removed, and
    ///   an array slot is emptied.
    /// - Intermediate containers are created on demand, and the shape of each one is decided by the
    ///   *next* segment: a numeric segment creates an Array, anything else an Object.
    /// - Callbacks run after the lock is released, so a subscriber may call back into the model.
    ///   Each callback receives the value read at notification time, not necessarily the newest one.
    public func set(_ path: String, _ value: StructuredValue?, scope: String = "") {
        lock.lock()
        let absolute = JSONPointer.absolutePath(path, scope: scope)
        if let value {
            JSONPointer.set(path: absolute, value: value, in: &root)
        } else {
            JSONPointer.remove(path: absolute, in: &root)
        }
        // Capture affected listeners under lock, fire outside the lock.
        let affected = listeners.values.filter { isAffected(listenerPath: $0.path, changedPath: absolute) }
        let snapshots = affected.map { listener -> (callback: (StructuredValue?) -> Void, value: StructuredValue?) in
            (listener.callback, JSONPointer.resolve(path: listener.path, in: root))
        }
        lock.unlock()

        for s in snapshots {
            s.callback(s.value)
        }
    }

    // MARK: - Subscribe

    /// Subscribes to changes at `path`, firing the callback **once synchronously** with the current
    /// value before returning.
    ///
    /// After that it fires on every write that affects the path under bubble & cascade: writes to
    /// the path itself, to any ancestor, and to any descendant. Because of the synchronous first
    /// call, the callback runs before the returned handle exists — do not capture the handle inside
    /// it. Retain the handle: dropping it cancels the subscription.
    @discardableResult
    public func subscribe(
        _ path: String,
        scope: String = "",
        _ onChange: @escaping (StructuredValue?) -> Void
    ) -> A2UISubscription {
        lock.lock()
        let absolute = JSONPointer.absolutePath(path, scope: scope)
        let token = nextToken
        nextToken += 1
        listeners[token] = (path: absolute, callback: onChange)
        let current = JSONPointer.resolve(path: absolute, in: root)
        lock.unlock()

        // Synchronous initial value (signal semantics).
        onChange(current)

        return A2UISubscription { [weak self] in
            guard let self else { return }
            self.lock.lock()
            self.listeners.removeValue(forKey: token)
            self.lock.unlock()
        }
    }

    // MARK: - Notification topology

    /// A listener at `listenerPath` is affected by a write at `changedPath` when either path is a
    /// prefix of the other (bubble = changed is descendant of listener; cascade = changed is
    /// ancestor of listener), or they are equal.
    private func isAffected(listenerPath: String, changedPath: String) -> Bool {
        if listenerPath == changedPath { return true }
        let l = normalize(listenerPath)
        let c = normalize(changedPath)
        return isPrefix(l, of: c) || isPrefix(c, of: l)
    }

    private func normalize(_ path: String) -> [String] {
        path.split(separator: "/", omittingEmptySubsequences: true).map(String.init)
    }

    /// True if `a` is a path-segment prefix of `b` (e.g. ["user"] is a prefix of ["user","name"]).
    private func isPrefix(_ a: [String], of b: [String]) -> Bool {
        guard a.count <= b.count else { return false }
        for i in a.indices where a[i] != b[i] { return false }
        return true
    }
}

import A2UICore
import Foundation

/// A reactive store for a single surface's application data.
///
/// Implements the `DataModel` contract from `renderer_guide.md` §3:
/// - JSON Pointer `get` / `set` (absolute + A2UI relative paths) with auto-vivification.
/// - Reactive `subscribe(path:)` that fires the current value synchronously, then on every
///   relevant change. Cancellation is provided via `A2UISubscription`.
/// - **Bubble & Cascade** notification: a write at `path` notifies subscribers of `path` itself,
///   of every ancestor path (bubble), and of every descendant path (cascade).
///
/// This is a reference type (not `@Observable`): SwiftUI does not subscribe to it directly —
/// the Binder layer translates path subscriptions into `@Observable` `ResolvedProps`.
public final class DataModel: @unchecked Sendable {

    private var root: AnyCodable
    private var listeners: [Int: (path: String, callback: (AnyCodable?) -> Void)] = [:]
    private var nextToken = 0
    private let lock = NSRecursiveLock()

    public init(_ initial: AnyCodable = .object([:])) {
        self.root = initial
    }

    /// Snapshot of the entire data model.
    public var snapshot: AnyCodable {
        lock.lock(); defer { lock.unlock() }
        return root
    }

    // MARK: - Read

    /// Resolve a path to its current value. Supports absolute (`/a/b`) and relative (`a/b`) paths.
    /// Returns nil when the path does not resolve (treated as `undefined` by callers).
    public func get(_ path: String, scope: String = "") -> AnyCodable? {
        lock.lock(); defer { lock.unlock() }
        return JSONPointer.resolve(path: path, scope: scope, in: root)
    }

    // MARK: - Write

    /// Set (or remove, when `value == nil`) the value at `path`, then notify affected subscribers.
    ///
    /// - `value == nil` removes the key (object) / empties the index preserving length (array),
    ///   per the spec's Undefined Handling rule.
    /// - Intermediate containers are auto-created; a numeric next-segment yields an Array.
    public func set(_ path: String, _ value: AnyCodable?, scope: String = "") {
        lock.lock()
        let absolute = JSONPointer.absolutePath(path, scope: scope)
        if let value {
            JSONPointer.set(path: absolute, value: value, in: &root)
        } else {
            JSONPointer.remove(path: absolute, in: &root)
        }
        // Capture affected listeners under lock, fire outside the lock.
        let affected = listeners.values.filter { isAffected(listenerPath: $0.path, changedPath: absolute) }
        let snapshots = affected.map { listener -> (callback: (AnyCodable?) -> Void, value: AnyCodable?) in
            (listener.callback, JSONPointer.resolve(path: listener.path, in: root))
        }
        lock.unlock()

        for s in snapshots {
            s.callback(s.value)
        }
    }

    // MARK: - Subscribe

    /// Subscribe to changes at `path`. The callback fires **synchronously once** with the current
    /// value, then again whenever a write affects this path (bubble & cascade).
    @discardableResult
    public func subscribe(
        _ path: String,
        scope: String = "",
        _ onChange: @escaping (AnyCodable?) -> Void
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

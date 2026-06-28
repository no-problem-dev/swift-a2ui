import A2UICore
import Foundation

/// 単一サーフェスのアプリケーションデータを保持するリアクティブストア。
///
/// `renderer_guide.md` §3 の `DataModel` 契約を実装する:
/// - JSON Pointer の `get` / `set`（絶対パス + A2UI 相対パス）と中間コンテナの自動生成。
/// - `subscribe(path:)`: 現在値を同期的に一度発火した後、関連する変更のたびに再発火。
///   キャンセルは `A2UISubscription` で行う。
/// - **Bubble & Cascade 通知**: `path` への書き込みは `path` 自身・すべての祖先（bubble）・
///   すべての子孫（cascade）のサブスクライバーへ通知する。
///
/// 参照型（`@Observable` ではない）。SwiftUI は直接購読しない。
/// Binder 層がパスサブスクリプションを `@Observable` の `ResolvedProps` に変換する。
public final class DataModel: @unchecked Sendable {

    private var root: StructuredValue
    private var listeners: [Int: (path: String, callback: (StructuredValue?) -> Void)] = [:]
    private var nextToken = 0
    private let lock = NSRecursiveLock()

    public init(_ initial: StructuredValue = .object([:])) {
        self.root = initial
    }

    /// データモデル全体のスナップショット。
    public var snapshot: StructuredValue {
        lock.lock(); defer { lock.unlock() }
        return root
    }

    // MARK: - Read

    /// パスを現在値に解決する。絶対パス（`/a/b`）と相対パス（`a/b`）の両方をサポート。
    /// パスが解決できない場合は nil を返す（呼び出し元は `undefined` として扱う）。
    public func get(_ path: String, scope: String = "") -> StructuredValue? {
        lock.lock(); defer { lock.unlock() }
        return JSONPointer.resolve(path: path, scope: scope, in: root)
    }

    // MARK: - Write

    /// `path` の値を設定（`value == nil` の場合は削除）し、影響するサブスクライバーへ通知する。
    ///
    /// - `value == nil` の場合: オブジェクトのキーを削除 / 配列のインデックスを空にする
    ///   （仕様の Undefined Handling ルールに準拠）。
    /// - 中間コンテナは自動生成される。数値の次セグメントは Array を生成する。
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

    /// `path` への変更をサブスクライブする。コールバックは現在値で**同期的に一度**発火し、
    /// その後この path に影響する書き込みのたびに再発火する（bubble & cascade）。
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

import A2UICore
import AGUICore

/// A2UI サーフェスの生成ライフサイクル(ペイント前の進捗通知)。
/// paint と同じ messageId に `replace: true` で流れ、最終的にペイントが置換する。
public struct A2UISurfaceLifecycle: Codable, Sendable, Equatable {
    /// 既知の status 値。
    public enum Kind: String, Sendable {
        case building
        case retrying
        case failed
    }

    /// wire 上の status 文字列。未知の値も受理する(前方互換)。
    public var status: String
    /// building: 生成済みトークン数の推定。
    public var progressTokens: Int?
    /// retrying: 現在の試行回数。
    public var attempt: Int?
    /// retrying / failed: 最大試行回数。
    public var maxAttempts: Int?
    /// retrying: 検証エラー一覧。
    public var errors: [A2UIGenerationIssue]?
    /// failed: 失敗理由。
    public var error: String?
    /// failed: 試行記録(形は実装依存のため生値のまま)。
    public var attempts: StructuredValue?
    /// サーバー設定によるデバッグ表示ヒント("hidden" / "collapsed" / "verbose")。
    public var debugExposure: String?

    public var kind: Kind? { Kind(rawValue: status) }

    public init(
        status: String,
        progressTokens: Int? = nil,
        attempt: Int? = nil,
        maxAttempts: Int? = nil,
        errors: [A2UIGenerationIssue]? = nil,
        error: String? = nil,
        attempts: StructuredValue? = nil,
        debugExposure: String? = nil
    ) {
        self.status = status
        self.progressTokens = progressTokens
        self.attempt = attempt
        self.maxAttempts = maxAttempts
        self.errors = errors
        self.error = error
        self.attempts = attempts
        self.debugExposure = debugExposure
    }

    public static func building(progressTokens: Int? = nil) -> A2UISurfaceLifecycle {
        A2UISurfaceLifecycle(status: Kind.building.rawValue, progressTokens: progressTokens)
    }

    public static func retrying(attempt: Int, maxAttempts: Int, errors: [A2UIGenerationIssue] = []) -> A2UISurfaceLifecycle {
        A2UISurfaceLifecycle(status: Kind.retrying.rawValue, attempt: attempt, maxAttempts: maxAttempts, errors: errors)
    }

    public static func failed(error: String, maxAttempts: Int? = nil) -> A2UISurfaceLifecycle {
        A2UISurfaceLifecycle(status: Kind.failed.rawValue, maxAttempts: maxAttempts, error: error)
    }
}

/// A2UI 生成の検証エラー(`{code, path, message}`)。
public struct A2UIGenerationIssue: Codable, Sendable, Equatable {
    public var code: String
    public var path: String?
    public var message: String?

    public init(code: String, path: String? = nil, message: String? = nil) {
        self.code = code
        self.path = path
        self.message = message
    }
}

/// `ACTIVITY_SNAPSHOT`(`activityType: "a2ui-surface"`)の content の 2 形態。
///
/// 判別規範(公式 recovery-gate テスト準拠):
/// paint = `a2ui_operations` が配列 / lifecycle = `status` が文字列。
public enum A2UIActivityContent: Sendable, Equatable {
    /// surface 本体。累積自己完結な A2UI 操作列(1 スナップショットで復元可能)。
    case paint([AgentMessage])
    /// ペイント前のライフサイクル通知。
    case lifecycle(A2UISurfaceLifecycle)

    public init(snapshot: ActivitySnapshotEvent) throws {
        guard snapshot.activityType == A2UIAGUIConstants.activityType else {
            throw AGUIError(
                "Not an A2UI activity: activityType=\(snapshot.activityType) (expected \(A2UIAGUIConstants.activityType))"
            )
        }
        try self.init(content: snapshot.content)
    }

    public init(content: StructuredValue) throws {
        if let operations = content.objectValue?[A2UIAGUIConstants.operationsKey] {
            guard let array = operations.arrayValue else {
                throw AGUIError("\(A2UIAGUIConstants.operationsKey) must be an array")
            }
            self = .paint(try StructuredValue.array(array).decode([AgentMessage].self))
        } else if content.objectValue?["status"]?.stringValue != nil {
            self = .lifecycle(try content.decode(A2UISurfaceLifecycle.self))
        } else {
            throw AGUIError(
                "A2UI activity content must contain either \(A2UIAGUIConstants.operationsKey) (paint) or status (lifecycle)"
            )
        }
    }
}

extension ActivitySnapshotEvent {
    /// サーバー側: paint スナップショットを構築する。
    ///
    /// 禁則(公式ソース明記): `createSurface` 単独の emit は不可 — レンダラが
    /// 未到着の root を解決しようとして落ちるため、必ず components を同梱する。
    public static func a2uiPaint(
        messageId: String,
        operations: [AgentMessage]
    ) throws -> ActivitySnapshotEvent {
        guard !operations.isEmpty else {
            throw AGUIError("A2UI paint snapshot requires at least one operation")
        }
        let hasCreateSurface = operations.contains {
            if case .createSurface = $0 { return true } else { return false }
        }
        let hasComponents = operations.contains {
            if case .updateComponents = $0 { return true } else { return false }
        }
        if hasCreateSurface, !hasComponents {
            throw AGUIError(
                "createSurface must be accompanied by updateComponents in the same snapshot"
            )
        }
        return ActivitySnapshotEvent(
            messageId: messageId,
            activityType: A2UIAGUIConstants.activityType,
            content: .object([
                A2UIAGUIConstants.operationsKey: try .encoded(operations),
            ]),
            replace: true
        )
    }

    /// サーバー側: ライフサイクルスナップショットを構築する。
    public static func a2uiLifecycle(
        messageId: String,
        _ lifecycle: A2UISurfaceLifecycle
    ) throws -> ActivitySnapshotEvent {
        ActivitySnapshotEvent(
            messageId: messageId,
            activityType: A2UIAGUIConstants.activityType,
            content: try .encoded(lifecycle),
            replace: true
        )
    }
}

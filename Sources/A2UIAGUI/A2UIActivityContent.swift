import StructuredDataCore
import A2UICore
import AGUICore

/// Progress of an A2UI surface while it is being generated, sent before the paint arrives.
/// It streams on the same messageId as the paint with `replace: true`, and the paint eventually
/// replaces it.
public struct A2UISurfaceLifecycle: Codable, Sendable, Equatable {
    /// The status values this package knows; `status` may carry others.
    public enum Kind: String, Sendable {
        case building
        case retrying
        case failed
    }

    /// The status string as it appears on the wire. Unknown values are accepted too, for forward
    /// compatibility.
    public var status: String
    /// building: estimated number of tokens generated so far.
    public var progressTokens: Int?
    /// retrying: the attempt currently under way.
    public var attempt: Int?
    /// retrying / failed: the maximum number of attempts.
    public var maxAttempts: Int?
    /// retrying: the validation errors that forced the retry.
    public var errors: [A2UIGenerationIssue]?
    /// failed: why generation failed.
    public var error: String?
    /// failed: the record of the attempts, kept as a raw value because its shape is
    /// implementation-defined.
    public var attempts: StructuredValue?
    /// Debug display hint from the server configuration ("hidden" / "collapsed" / "verbose").
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

/// A validation error raised while generating A2UI (`{code, path, message}`).
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

/// The two content shapes an `ACTIVITY_SNAPSHOT` with `activityType: "a2ui-surface"` can carry.
///
/// Discrimination rule, matching the upstream recovery-gate tests:
/// paint = `a2ui_operations` is an array / lifecycle = `status` is a string.
public enum A2UIActivityContent: Sendable, Equatable {
    /// The surface itself: a cumulative, self-contained operation sequence, so a single snapshot
    /// restores the whole surface.
    case paint([AgentMessage])
    /// A lifecycle notification sent before the paint.
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
    /// Server side: builds a paint snapshot.
    ///
    /// A **surface with no contents** must not be emitted, because the renderer would try to
    /// resolve a root that never arrives and crash; such a snapshot is rejected here.
    ///
    /// In v1.0 `createSurface` can carry its own `components`, which satisfies the requirement
    /// (the append-only, single-message shape). Sending a separate `updateComponents`, as in
    /// v0.9, satisfies it as well. Only a snapshot that does neither is rejected.
    public static func a2uiPaint(
        messageId: String,
        operations: [AgentMessage]
    ) throws -> ActivitySnapshotEvent {
        guard !operations.isEmpty else {
            throw AGUIError("A2UI paint snapshot requires at least one operation")
        }
        let createdSurfaces = operations.compactMap { operation -> CreateSurface? in
            if case .createSurface(let cs) = operation { return cs } else { return nil }
        }
        let surfacesGettingComponents = Set(operations.compactMap { operation -> String? in
            if case .updateComponents(let uc) = operation { return uc.surfaceId } else { return nil }
        })
        for surface in createdSurfaces {
            let hasInlineComponents = !(surface.components ?? []).isEmpty
            guard hasInlineComponents || surfacesGettingComponents.contains(surface.surfaceId) else {
                throw AGUIError(
                    "createSurface '\(surface.surfaceId)' carries no components:"
                        + " pass them inline (v1.0) or send updateComponents in the same snapshot"
                )
            }
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

    /// Server side: builds a lifecycle snapshot for the same messageId the paint will replace.
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

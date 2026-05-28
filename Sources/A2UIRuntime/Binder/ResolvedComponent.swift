import A2UICore
import A2UISurface
import Foundation
import Observation

/// A reactive, fully-resolved view of a single component's properties — the foundation the
/// consumer's SwiftUI layer reads from (spec §5 "Binder Layer Pattern").
///
/// `@Observable` so a SwiftUI `View` can read `props`/`children`/`validationMessage` directly and
/// re-render automatically. The library owns the complexity of subscribing to data bindings,
/// evaluating functions/checks, and expanding template children; the consumer just renders.
///
/// Ownership (spec §6): the consumer creates a `ResolvedComponent` when a component mounts and
/// calls `dispose()` when it unmounts to release all data-model subscriptions.
@MainActor
@Observable
public final class ResolvedComponent {
    /// The component id and type.
    public let id: String
    public let type: String

    /// Data props with all `Dynamic*` values resolved to concrete `AnyCodable`.
    /// Updates reactively whenever a bound data-model path changes.
    public private(set) var props: [String: AnyCodable] = [:]

    /// Structural children (resolved from `child`/`children`/`trigger`/`content`/`tabs`).
    /// For template `children`, this expands to one slot per data element.
    public private(set) var children: [ResolvedChild] = []

    /// The first failing check's message (spec `checks`), or nil if all pass.
    /// When non-nil for a Button, the consumer should disable it.
    public private(set) var validationMessage: String?

    @ObservationIgnored
    private let context: ComponentContext
    @ObservationIgnored
    private var subscriptions: [A2UISubscription] = []
    @ObservationIgnored
    private let functions: any FunctionResolving

    /// Property keys treated as structural (resolved into `children`, not `props`).
    private static let structuralKeys: Set<String> = ["child", "children", "trigger", "content", "tabs"]

    public init(context: ComponentContext, functions: any FunctionResolving = NoFunctionResolver()) {
        self.id = context.componentId
        self.type = context.componentType
        self.context = context
        self.functions = functions
        bind()
    }

    /// This node's data scope (JSON Pointer). Empty string = root. Template instances carry their
    /// element scope (e.g. `/items/2`), so two-way writes land at the correct path.
    public var scope: String { context.dataContext.path }

    /// Dispatch a user action declared by this component (e.g. a Button's `action.event`).
    public func dispatch(name: String, context actionContext: [String: AnyCodable]) {
        context.dispatch(name, actionContext)
    }

    // MARK: - Two-way binding (spec §"Two-way binding & input components")

    /// The raw (unresolved) binding path for a prop, if the prop is a `{ "path": ... }` binding.
    /// Input components write back through this path; nil when the prop is a literal/function.
    public func bindingPath(_ key: String) -> String? {
        guard case .object(let dict)? = context.properties[key],
              case .string(let path)? = dict["path"], dict.count == 1 else {
            return nil
        }
        return path
    }

    /// Write a new value for a two-way-bound prop back into the data model (View → Model).
    /// No-op when the prop is not a binding. Resolves the path against this node's scope, so the
    /// data model updates and all subscribers (incl. sibling Text labels) re-render reactively.
    public func write(_ key: String, _ value: AnyCodable?) {
        guard let path = bindingPath(key) else { return }
        context.dataContext.set(path, value)
    }

    /// Release all data-model subscriptions. Call on unmount (spec §6 cleanup).
    public func dispose() {
        for sub in subscriptions { sub.cancel() }
        subscriptions.removeAll()
    }

    // MARK: - Binding

    private func bind() {
        rebuildStructural()
        bindDataProps()
        bindChecks()
    }

    /// Subscribe to every non-structural property, resolving embedded bindings/functions reactively.
    private func bindDataProps() {
        for (key, raw) in context.properties where !Self.structuralKeys.contains(key) && key != "checks" && key != "action" {
            if containsDynamic(raw) {
                let sub = subscribeResolved(raw) { [weak self] resolved in
                    self?.props[key] = resolved
                }
                subscriptions.append(sub)
            } else {
                props[key] = raw
            }
        }
    }

    /// Re-expand structural children against the current scope.
    private func rebuildStructural() {
        var result: [ResolvedChild] = []
        // Single-child structural fields.
        for key in ["child", "trigger", "content"] {
            if case .string(let childId)? = context.properties[key] {
                result.append(ResolvedChild(componentId: childId, basePath: context.dataContext.path))
            }
        }
        // children: static list or data-bound template.
        if let childrenRaw = context.properties["children"],
           let expanded = TemplateExpander.expandRaw(childrenRaw, in: context.dataContext) {
            result.append(contentsOf: expanded)
        }
        // tabs: array of objects each with a "child".
        if case .array(let tabs)? = context.properties["tabs"] {
            for tab in tabs {
                if case .object(let dict) = tab, case .string(let childId)? = dict["child"] {
                    result.append(ResolvedChild(componentId: childId, basePath: context.dataContext.path))
                }
            }
        }
        children = result
    }

    private func bindChecks() {
        guard case .array(let rawChecks)? = context.properties["checks"], !rawChecks.isEmpty else { return }
        let checks = decodeChecks(rawChecks)
        guard !checks.isEmpty else { return }
        // Re-evaluate checks on every relevant data change by subscribing to each referenced path.
        // Simplest correct approach: subscribe to the whole data model root via each check's
        // condition resolution. Here we re-evaluate eagerly and on any bound prop change.
        evaluateChecks(checks)
        for path in referencedPaths(in: rawChecks) {
            let sub = context.dataContext.dataModel.subscribe(path, scope: context.dataContext.path) { [weak self] _ in
                guard let self else { return }
                self.evaluateChecks(checks)
            }
            subscriptions.append(sub)
        }
    }

    private func evaluateChecks(_ checks: [CheckRule]) {
        validationMessage = ChecksEvaluator.firstFailure(checks, in: context.dataContext)
    }

    // MARK: - Helpers

    /// Subscribe to a raw property that contains a binding or function call, delivering resolved values.
    private func subscribeResolved(_ raw: AnyCodable, _ onChange: @escaping (AnyCodable) -> Void) -> A2UISubscription {
        // Direct binding object: subscribe to the path.
        if case .object(let dict) = raw, case .string(let path)? = dict["path"], dict.count == 1 {
            return context.dataContext.dataModel.subscribe(path, scope: context.dataContext.path) { value in
                onChange(value ?? .null)
            }
        }
        // Function call or nested: evaluate once (re-evaluation hooks would need dependency tracking;
        // for function-driven props the consumer can re-resolve on demand). Fire initial value.
        let resolved = ArgResolver.resolve(raw, in: context.dataContext, functions: functions)
        onChange(resolved ?? .null)
        return .inert
    }

    private func containsDynamic(_ value: AnyCodable) -> Bool {
        switch value {
        case .object(let dict):
            if dict["path"] != nil || dict["call"] != nil { return true }
            return dict.values.contains(where: containsDynamic)
        case .array(let arr):
            return arr.contains(where: containsDynamic)
        default:
            return false
        }
    }

    private func decodeChecks(_ raw: [AnyCodable]) -> [CheckRule] {
        raw.compactMap { item in
            guard let data = try? JSONEncoder().encode(item) else { return nil }
            return try? JSONDecoder().decode(CheckRule.self, from: data)
        }
    }

    /// Collect data-model paths referenced anywhere inside the checks, so we can re-evaluate on change.
    private func referencedPaths(in raw: [AnyCodable]) -> Set<String> {
        var paths: Set<String> = []
        func walk(_ value: AnyCodable) {
            switch value {
            case .object(let dict):
                if case .string(let p)? = dict["path"] { paths.insert(p) }
                for v in dict.values { walk(v) }
            case .array(let arr):
                for v in arr { walk(v) }
            default:
                break
            }
        }
        for item in raw { walk(item) }
        return paths
    }
}

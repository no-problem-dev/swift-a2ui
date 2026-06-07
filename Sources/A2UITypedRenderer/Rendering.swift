import SwiftUI
import DesignSystem
import A2UICore
import A2UIRuntime
import A2UITyped

/// A catalog that knows how to render its `Node` into SwiftUI.
///
/// Kept separate from `A2UICatalog` (which is UI-agnostic) so the typed catalog core has no SwiftUI
/// dependency. A conformer supplies a `@ViewBuilder switch` over its node sum type — exhaustive and
/// type-safe, with no string matching and no `AnyView`.
@MainActor
public protocol RenderableCatalog: A2UICatalog {
    associatedtype NodeBody: View
    static func view(for node: Node, in ctx: RenderContext<Self>) -> NodeBody
}

/// The render-time context handed to a catalog's `view(for:in:)`: data scope + child rendering.
///
/// Generic over the catalog — this is the "viral generics" cost made concrete, and the price of
/// zero erasure: `child(_:)` returns a *concrete* `NodeView<Catalog>`, never `AnyView`.
@MainActor
public struct RenderContext<Catalog: RenderableCatalog> {
    let surface: TypedSurface<Catalog>
    let scope: String
    /// DesignSystem palette for the current environment (theme/dark mode). Read by leaf views.
    let colors: any ColorPalette
    /// Environment URL opener — the sole side-effect sink for `functionCall: openUrl` (matches the
    /// old ClientFunctions path). Defaults to a no-op for tests / non-view construction.
    let openURL: OpenURLAction

    init(
        surface: TypedSurface<Catalog>,
        scope: String,
        colors: any ColorPalette = LightColorPalette(),
        openURL: OpenURLAction = OpenURLAction { _ in .discarded }
    ) {
        self.surface = surface
        self.scope = scope
        self.colors = colors
        self.openURL = openURL
    }

    /// Data context for the current scope, with the Basic Catalog function registry wired in so
    /// `{call: …}` dynamic values AND `checks` (which are function calls) actually resolve.
    var dataContext: DataContext {
        DataContext(dataModel: surface.dataModel, path: scope, functions: BasicFunctions())
    }

    // MARK: - Client-side validation (`checks` / Checkable)

    /// True when every check passes (or there are none). Spec: a Button with failing checks is
    /// disabled. Tracks the data version so edits re-evaluate the checks reactively.
    public func checksPass(_ checks: [CheckRule]?) -> Bool {
        guard let checks, !checks.isEmpty else { return true }
        trackData()
        return ChecksEvaluator.allPass(checks, in: dataContext)
    }

    /// The first failing check's message (the active validation error), or nil. Reactive.
    public func firstCheckFailure(_ checks: [CheckRule]?) -> String? {
        guard let checks, !checks.isEmpty else { return nil }
        trackData()
        return ChecksEvaluator.firstFailure(checks, in: dataContext)
    }

    /// Resolve a bindable string (`literal` / `{path}` / `{call}`) against the current scope.
    /// Non-literal values track `dataVersion` so a data-model update re-renders the reader.
    public func resolve(_ value: DynamicString) -> String {
        if case .literal = value {} else { trackData() }
        return dataContext.resolveString(value)
    }
    public func resolveBool(_ value: DynamicBoolean) -> Bool {
        if case .literal = value {} else { trackData() }
        return dataContext.resolveBool(value)
    }
    public func resolveNumber(_ value: DynamicNumber) -> Double {
        if case .literal = value {} else { trackData() }
        return dataContext.resolveNumber(value)
    }

    /// Establish a SwiftUI dependency on the surface's data version (reactivity for bindings).
    private func trackData() { _ = surface.dataVersion }

    /// Dispatch a component `action`:
    /// - `.event` → resolve its context args against scope and hand to the host (`onEvent`).
    /// - `.functionCall openUrl` → resolve the `url` arg and open it via the environment opener.
    public func dispatch(_ action: Action, from sourceId: ComponentId = "") {
        switch action {
        case .event(let event):
            var resolved: [String: StructuredValue] = [:]
            for (key, value) in event.context ?? [:] { resolved[key] = dataContext.resolve(value) ?? .null }
            surface.onEvent(event.name, resolved, sourceId)
        case .functionCall(let call):
            if call.call == "openUrl",
               case .string(let raw)? = resolveArg(call.args?["url"]),
               let url = URL(string: raw) {
                openURL(url)
            }
        }
    }

    /// Resolve a function-call argument that may be a literal or a `{path}` binding.
    private func resolveArg(_ value: StructuredValue?) -> StructuredValue? {
        guard let value else { return nil }
        if case .object(let dict) = value, case .string(let path)? = dict["path"], dict.count == 1 {
            return surface.dataModel.get(path, scope: scope)
        }
        return value
    }

    /// Render a child by id — the recursive seam, kept type-safe via the nominal `NodeView`.
    public func child(_ id: ComponentId) -> NodeView<Catalog> {
        NodeView(surface: surface, id: id, scope: scope)
    }

    /// Resolve a `ChildList` into concrete child slots, expanding `{componentId, path}` templates
    /// over the bound collection (spec §collection scopes). Expansion reads the data model, so it
    /// tracks `dataVersion` — collection changes re-render the container. Mirrors the official lit
    /// renderer's `A2uiChildRef` shape (`{id, basePath}`, scope = basePath ?? parentPath).
    public func children(_ list: ChildList) -> [ResolvedChild] {
        if case .template = list { trackData() }
        return TemplateExpander.expand(list, in: dataContext)
    }

    /// Render a resolved child slot — template instances carry their element scope (`basePath`).
    public func child(_ resolved: ResolvedChild) -> NodeView<Catalog> {
        NodeView(surface: surface, id: resolved.componentId, scope: resolved.basePath)
    }

    /// Look up a child node (e.g. to inspect its kind for layout decisions, type-safely).
    public func node(_ id: ComponentId) -> CatalogNode<Catalog.Node>? { surface.node(id) }

    // MARK: - Two-way binding (inputs write back to the data model at the bound path)

    /// Write a value at `path` (resolved against scope) and re-resolve dependent views.
    public func write(_ path: String, _ value: StructuredValue?) {
        dataContext.set(path, value)
        surface.touchData()
    }

    /// A `Binding<String>` over a `DynamicString`: reads resolve; writes hit the bound path (no-op
    /// for literals, which have nowhere to write — mirrors the old `Writable` semantics).
    public func binding(_ value: DynamicString?) -> Binding<String> {
        Binding(
            get: { value.map { self.resolve($0) } ?? "" },
            set: { newValue in if case .binding(let b)? = value { self.write(b.path, .string(newValue)) } }
        )
    }
    public func binding(_ value: DynamicBoolean) -> Binding<Bool> {
        Binding(
            get: { self.resolveBool(value) },
            set: { newValue in if case .binding(let b) = value { self.write(b.path, .bool(newValue)) } }
        )
    }
    public func binding(_ value: DynamicNumber) -> Binding<Double> {
        Binding(
            get: { self.resolveNumber(value) },
            set: { newValue in if case .binding(let b) = value { self.write(b.path, .double(newValue)) } }
        )
    }

    /// Resolve a `DynamicStringList` (ChoicePicker selection) to its current `[String]`.
    public func resolveStringList(_ value: DynamicStringList) -> [String] {
        if case .literal = value {} else { trackData() }
        switch value {
        case .literal(let list): return list
        case .binding(let b):
            guard case .array(let arr)? = surface.dataModel.get(b.path, scope: scope) else { return [] }
            return arr.compactMap { if case .string(let s) = $0 { return s } else { return nil } }
        case .functionCall: return []
        }
    }

    public func writeStringList(_ value: DynamicStringList, _ list: [String]) {
        if case .binding(let b) = value { write(b.path, .array(list.map { .string($0) })) }
    }
}

/// Recursive dispatcher: resolves one id to its node and renders it. `.known` delegates to the
/// catalog's exhaustive view mapping; `.unknown` shows the spec-mandated graceful fallback.
@MainActor
public struct NodeView<Catalog: RenderableCatalog>: View {
    @Environment(\.colorPalette) private var colors
    @Environment(\.openURL) private var openURL
    let surface: TypedSurface<Catalog>
    let id: ComponentId
    let scope: String

    public var body: some View {
        if let node = surface.node(id) {
            switch node {
            case .known(let known):
                Catalog.view(for: known, in: RenderContext(
                    surface: surface, scope: scope, colors: colors, openURL: openURL))
            case .unknown(let name, _, _):
                UnknownComponentView(name: name)
            }
        }
    }
}

/// Entry point: render a whole surface from its root. Faithful port of A2UIRenderer.SurfaceView,
/// including the `busy` treatment (disable + dim + "実行中" pill) and the generating placeholder.
@MainActor
public struct A2UISurfaceView<Catalog: RenderableCatalog>: View {
    @Environment(\.colorPalette) private var colors
    @Environment(\.spacingScale) private var spacing
    let surface: TypedSurface<Catalog>
    let busy: Bool

    public init(_ surface: TypedSurface<Catalog>, busy: Bool = false) {
        self.surface = surface
        self.busy = busy
    }

    public var body: some View {
        content
            .disabled(busy)
            .opacity(busy ? 0.55 : 1)
            .overlay(alignment: .topTrailing) { if busy { busyPill } }
            .animation(.easeInOut(duration: 0.2), value: busy)
            // ストリーミングで部品が流れ込むたびに、挿入トランジション（カードの
            // フェード+スケール等）をアニメーション付きで再生する（カスケード組み上がり）
            .animation(.smooth(duration: 0.45), value: surface.structureVersion)
    }

    @ViewBuilder private var content: some View {
        if surface.node(surface.rootId) != nil {
            NodeView(surface: surface, id: surface.rootId, scope: "")
        } else {
            HStack(spacing: spacing.sm) {
                ProgressView().controlSize(.small)
                Text("UI を生成中…").foregroundStyle(colors.onSurfaceVariant)
            }
        }
    }

    private var busyPill: some View {
        HStack(spacing: spacing.xs) {
            ProgressView().controlSize(.small)
            Text("実行中").typography(.labelSmall).foregroundStyle(colors.onSurface)
        }
        .padding(.horizontal, spacing.sm)
        .padding(.vertical, spacing.xxs)
        .background(colors.surface, in: Capsule())
        .overlay(Capsule().stroke(colors.outlineVariant, lineWidth: 1))
        .shadow(color: colors.shadow.opacity(0.12), radius: 4, y: 2)
        .padding(spacing.xs)
    }
}

/// Spec fallback for a component the catalog does not implement (A2UI renderer guide: never crash —
/// show a "Not Supported" placeholder or skip).
struct UnknownComponentView: View {
    let name: String
    var body: some View {
        Text("⚠️ Unsupported: \(name)")
            .font(.caption)
            .foregroundStyle(.secondary)
    }
}

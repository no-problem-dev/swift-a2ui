import StructuredDataCore
import SwiftUI
import DesignSystem
import A2UICore
import A2UIRuntime
import A2UISurface
import A2UITyped

/// A catalog that also knows how to draw its own `Node` into SwiftUI.
///
/// Kept separate from the UI-agnostic `A2UICatalog` so the typed catalog core never picks up a
/// SwiftUI dependency. A conformer writes one `@ViewBuilder switch` covering the node sum type:
/// no string matching, no `AnyView`, and a missing case is a compile error.
@MainActor
public protocol RenderableCatalog: A2UICatalog {
    associatedtype NodeBody: View
    static func view(for node: Node, in ctx: RenderContext<Self>) -> NodeBody
}

/// Render-time context handed to a catalog's `view(for:in:)`: the data scope plus child rendering.
///
/// Generic over the catalog — that genericity is viral, and is the concrete price of zero type
/// erasure. What it buys is that `child(_:)` returns a named `NodeView<Catalog>`, not an `AnyView`.
@MainActor
public struct RenderContext<Catalog: RenderableCatalog> {
    let surface: TypedSurface<Catalog>
    let scope: String
    /// Zero-based index of the template iteration (collection scope).
    /// `nil` outside an iteration, where the built-in `@index` does not evaluate (spec v1.0).
    let collectionIndex: Int?
    /// Design system color palette (theme / dark mode), lifted out of the environment by
    /// `NodeView` so leaf views can color themselves without each reading the environment.
    let colors: any ColorPalette
    /// The environment's URL opener — the only side-effect sink on the `functionCall: openUrl`
    /// path. Defaults to a discarding action, so a context built outside a view hierarchy
    /// (tests, previews) opens nothing.
    let openURL: OpenURLAction

    init(
        surface: TypedSurface<Catalog>,
        scope: String,
        collectionIndex: Int? = nil,
        colors: any ColorPalette = LightColorPalette(),
        openURL: OpenURLAction = OpenURLAction { _ in .discarded }
    ) {
        self.surface = surface
        self.scope = scope
        self.collectionIndex = collectionIndex
        self.colors = colors
        self.openURL = openURL
    }

    /// Data context for the current scope, pre-wired with the Basic catalog's function registry
    /// so that `{call: …}` dynamic values and `checks` (which are function calls) actually resolve.
    var dataContext: DataContext {
        DataContext(
            dataModel: surface.dataModel,
            path: scope,
            collectionIndex: collectionIndex,
            functions: BasicFunctions()
        )
    }

    // MARK: - Client-side validation (`checks` / Checkable)

    /// Returns true when every check passes, and when there are no checks at all.
    ///
    /// Per the spec a `Button` whose checks fail is disabled. Reading this tracks the data
    /// version, so the checks are re-evaluated on every edit rather than once at build time.
    public func checksPass(_ checks: [CheckRule]?) -> Bool {
        guard let checks, !checks.isEmpty else { return true }
        trackData()
        return ChecksEvaluator.allPass(checks, in: dataContext)
    }

    /// Message of the first failing check — the currently active validation error — or `nil`.
    /// Re-evaluated on every data edit, so an input can show and clear its error as the user types.
    public func firstCheckFailure(_ checks: [CheckRule]?) -> String? {
        guard let checks, !checks.isEmpty else { return nil }
        trackData()
        return ChecksEvaluator.firstFailure(checks, in: dataContext)
    }

    /// Resolves a bindable string (`literal` / `{path}` / `{call}`) against the current scope.
    ///
    /// A non-literal value tracks `dataVersion`, so a data model update redraws the reading view.
    /// A literal deliberately does not, and stays inert.
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

    /// Establishes the SwiftUI dependency on the surface's data version — the one read that makes
    /// bindings reactive. Skip it and the view keeps a stale value until something else redraws it.
    private func trackData() { _ = surface.dataVersion }

    /// Dispatches a component's `action`.
    ///
    /// - `.event` resolves the context arguments against the scope and hands them to the host
    ///   through `onEvent`.
    /// - `.functionCall openUrl` resolves the `url` argument and opens it with the environment's
    ///   URL opener. Any other function call is dropped here.
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

    /// Resolves a function-call argument, which is either a literal or a `{path}` binding.
    /// Only a single-key `{"path": …}` object counts as a binding; anything else passes through.
    private func resolveArg(_ value: StructuredValue?) -> StructuredValue? {
        guard let value else { return nil }
        if case .object(let dict) = value, case .string(let path)? = dict["path"], dict.count == 1 {
            return surface.dataModel.get(path, scope: scope)
        }
        return value
    }

    /// Renders a child by id — the recursive seam, kept type-safe by returning a named `NodeView`.
    ///
    /// Carries the iteration scope through, so a child nested inside a template instance can still
    /// use `@index`.
    public func child(_ id: ComponentId) -> NodeView<Catalog> {
        NodeView(surface: surface, id: id, scope: scope, collectionIndex: collectionIndex)
    }

    /// Resolves a `ChildList` into concrete child slots, expanding a `{componentId, path}` template
    /// across the bound collection (spec §collection scopes).
    ///
    /// Expansion reads the data model, so it tracks `dataVersion` and a change to the collection
    /// redraws the container. Follows the `A2uiChildRef` shape of the reference lit renderer —
    /// `{id, basePath}`, with scope = basePath ?? parentPath.
    public func children(_ list: ChildList) -> [ResolvedChild] {
        if case .template = list { trackData() }
        return TemplateExpander.expand(list, in: dataContext)
    }

    /// Renders a resolved child slot: a template instance brings its element scope (`basePath`)
    /// and its iteration index for `@index`, while a child listed in a static `ids` array has none.
    public func child(_ resolved: ResolvedChild) -> NodeView<Catalog> {
        NodeView(
            surface: surface,
            id: resolved.componentId,
            scope: resolved.basePath,
            collectionIndex: resolved.collectionIndex
        )
    }

    /// Looks up a child node, for instance to check its kind type-safely before deciding a layout —
    /// the alternative to sniffing component names as strings.
    public func node(_ id: ComponentId) -> CatalogNode<Catalog.Node>? { surface.node(id) }

    // MARK: - Two-way binding (inputs write back to the data model at the bound path)

    /// Writes a value at `path`, resolved against the current scope, and bumps the data version so
    /// dependent views re-resolve.
    public func write(_ path: String, _ value: StructuredValue?) {
        dataContext.set(path, value)
        surface.touchData()
    }

    /// A `Binding<String>` over a `DynamicString`: reads resolve, writes land on the bound path.
    ///
    /// A literal has nowhere to write to, so setting it is silently dropped — an input bound to a
    /// literal will appear to reject every keystroke.
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

    /// Resolves a `DynamicStringList` — a ChoicePicker's selection — to the current `[String]`.
    ///
    /// Non-string entries are skipped. A `functionCall` is evaluated like any other dynamic value:
    /// an array yields its string entries and a single value yields a one-element list, which is
    /// the shape a mutually-exclusive picker binds to. It used to return `[]` outright, so a
    /// function-backed picker showed nothing selected however the function answered.
    public func resolveStringList(_ value: DynamicStringList) -> [String] {
        if case .literal = value {} else { trackData() }
        switch value {
        case .literal(let list): return list
        case .binding(let b):
            return stringList(surface.dataModel.get(b.path, scope: scope))
        case .functionCall(let call):
            return stringList(dataContext.resolve(DynamicValue.functionCall(call)))
        }
    }

    /// The strings in a resolved value: an array contributes its string entries, and any other
    /// non-empty value is coerced to a single entry.
    private func stringList(_ value: StructuredValue?) -> [String] {
        switch value {
        case .array(let entries):
            return entries.compactMap { if case .string(let s) = $0 { return s } else { return nil } }
        case .none, .null:
            return []
        case .some(let single):
            let text = A2UISurface.TypeCoercion.toString(single)
            return text.isEmpty ? [] : [text]
        }
    }

    public func writeStringList(_ value: DynamicStringList, _ list: [String]) {
        if case .binding(let b) = value { write(b.path, .array(list.map { .string($0) })) }
    }
}

/// Recursive dispatcher that resolves a single id to a node and draws it.
///
/// `.known` delegates to the catalog's exhaustive view mapping; `.unknown` shows the graceful
/// fallback the spec asks for. An id that resolves to nothing renders as empty, not as an error.
@MainActor
public struct NodeView<Catalog: RenderableCatalog>: View {
    @Environment(\.colorPalette) private var colors
    @Environment(\.openURL) private var openURL
    let surface: TypedSurface<Catalog>
    let id: ComponentId
    let scope: String
    /// Index of the template iteration (collection scope); `nil` outside an iteration.
    var collectionIndex: Int?

    public var body: some View {
        if let node = surface.node(id) {
            switch node {
            case .known(let known):
                Catalog.view(for: known, in: RenderContext(
                    surface: surface, scope: scope, collectionIndex: collectionIndex,
                    colors: colors, openURL: openURL))
            case .unknown(let name, _, _):
                UnknownComponentView(name: name)
            }
        }
    }
}

/// Entry point that renders a whole surface starting from its root component.
///
/// `busy` disables the tree, dims it, and floats a progress pill over the top-trailing corner;
/// before the root component arrives the view shows a generating placeholder rather than nothing.
@MainActor
public struct A2UISurfaceView<Catalog: RenderableCatalog>: View {
    @Environment(\.colorPalette) private var colors
    @Environment(\.spacingScale) private var spacing
    @Environment(\.motion) private var motion
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
            .animation(motion.fadeIn, value: busy)
            // Every batch of streamed-in components replays the insertion transition (a card's
            // fade + scale, say), so the surface assembles in a cascade instead of popping in.
            .animation(motion.stream, value: surface.structureVersion)
    }

    @ViewBuilder private var content: some View {
        if surface.node(surface.rootId) != nil {
            NodeView(surface: surface, id: surface.rootId, scope: "")
        } else {
            HStack(spacing: spacing.sm) {
                ProgressView().controlSize(.small)
                Text(RendererStrings.generatingUI()).foregroundStyle(colors.onSurfaceVariant)
            }
        }
    }

    private var busyPill: some View {
        HStack(spacing: spacing.xs) {
            ProgressView().controlSize(.small)
            Text(RendererStrings.busy()).typography(.labelSmall).foregroundStyle(colors.onSurface)
        }
        .padding(.horizontal, spacing.sm)
        .padding(.vertical, spacing.xxs)
        .background(colors.surface, in: Capsule())
        .overlay(Capsule().stroke(colors.outlineVariant, lineWidth: 1))
        // elevation adapts its opacity in dark mode; a hand-rolled shadow would stay fixed.
        .elevation(.level1)
        .padding(spacing.xs)
    }
}

/// Spec fallback for a component the catalog does not implement (A2UI renderer guide: never crash —
/// show a "Not Supported" placeholder or skip).
struct UnknownComponentView: View {
    @Environment(\.colorPalette) private var colors
    let name: String
    var body: some View {
        Text("⚠️ Unsupported: \(name)")
            .typography(.labelSmall)
            .foregroundStyle(colors.onSurfaceVariant)
    }
}

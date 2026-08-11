import SwiftUI
import DesignSystem
import SwiftMarkdownView
import SwiftMarkdownViewDesignSystem
import A2UICore
import A2UICatalog
import A2UIRuntime
import A2UITyped

/// Draws the Basic catalog into SwiftUI through one `@ViewBuilder switch` over `BasicComponent`.
///
/// No string matching, no `AnyView`, and no `default` escape hatch, so adding a component to the
/// catalog fails to compile until it is drawn here. The layout components (`Row` / `Column` /
/// `List`) are driven by `justify` and `align` alone rather than by sniffing what their children
/// are, which is what keeps a chip heuristic from quietly overriding an explicit `spaceBetween`.
extension BasicCatalog: RenderableCatalog {
    public static func view(for node: BasicComponent, in ctx: RenderContext<BasicCatalog>) -> some View {
        BasicComponentView(component: node, ctx: ctx)
    }
}

/// Draws a `BasicComponent` inside any catalog that embeds one — the renderer-side counterpart of
/// `CombinedNode` composition. A composed catalog's `view(for:in:)` delegates its basic case here:
///
/// ```swift
/// extension AppCatalog: RenderableCatalog {
///     static func view(for node: Node, in ctx: RenderContext<AppCatalog>) -> some View {
///         switch node {
///         case .primary(let mine): MyComponentView(mine, ctx)
///         case .fallback(let basic): BasicComponentView(component: basic, ctx: ctx)
///         }
///     }
/// }
/// ```
@MainActor
public struct BasicComponentView<Catalog: RenderableCatalog>: View where Catalog.Node: BasicEmbeddingNode {
    let component: BasicComponent
    let ctx: RenderContext<Catalog>

    public init(component: BasicComponent, ctx: RenderContext<Catalog>) {
        self.component = component
        self.ctx = ctx
    }

    public var body: some View {
        switch component {
        case .text(let c):
            textView(c, in: ctx)

        case .image(let c):
            ImageNodeView(component: c, ctx: ctx)

        case .icon(let c):
            Image(systemName: symbol(for: c.name, in: ctx))
                .iconSize(.md)
                .foregroundStyle(ctx.colors.onSurfaceVariant)

        case .video(let c):
            MediaNodeView(url: ctx.resolve(c.url), kind: .video, ctx: ctx)

        case .audioPlayer(let c):
            MediaNodeView(url: ctx.resolve(c.url), kind: .audio, ctx: ctx)

        case .row(let c):
            RowNodeView(component: c, ctx: ctx)

        case .column(let c):
            ColumnNodeView(component: c, ctx: ctx)

        case .list(let c):
            ListNodeView(component: c, ctx: ctx)

        case .card(let c):
            // Solid or glass is decided by the host's `surfaceStyle` environment, which the design
            // system's Card resolves. Insertion and scroll depth live in CardMotionModifier.
            Card(elevation: .level1) { ctx.child(c.child) }
                .modifier(CardMotionModifier())

        case .tabs(let c):
            TabsNodeView(component: c, ctx: ctx)

        case .modal(let c):
            ModalNodeView(component: c, ctx: ctx)

        case .divider(let c):
            if c.axis == .vertical {
                Rectangle().fill(ctx.colors.outlineVariant).frame(width: 1)
            } else {
                Rectangle().fill(ctx.colors.outlineVariant).frame(height: 1)
            }

        case .button(let c):
            ButtonNodeView(component: c, ctx: ctx)

        case .textField(let c):
            TextFieldNodeView(component: c, ctx: ctx)

        case .checkBox(let c):
            CheckBoxNodeView(component: c, ctx: ctx)

        case .slider(let c):
            SliderNodeView(component: c, ctx: ctx)

        case .choicePicker(let c):
            ChoicePickerNodeView(component: c, ctx: ctx)

        case .dateTimeInput(let c):
            DateTimeInputNodeView(component: c, ctx: ctx)
        }
    }

    // MARK: - Display helpers (faithful port of A2UIRenderer.TextView / Mappings)

    @ViewBuilder
    private func textView(_ c: TextComponent, in ctx: RenderContext<Catalog>) -> some View {
        let text = ctx.resolve(c.text)
        if shouldRenderMarkdown(text, variant: c.variant) {
            // MarkdownView draws through TextKit, so it does not inherit `.foregroundStyle`
            // the way the two branches below do — it reads its colors from the Markdown
            // environment. Without this the body fell back to `DefaultMarkdownPalette`, whose
            // `.primary` resolves against the *system* appearance rather than the A2UI theme:
            // a light surface under a dark-appearance host rendered white text on white.
            // Since A2UI v1.0 routes every heading and emphasis through markdown, that is the
            // common path, not an edge case.
            MarkdownView(text)
                .markdownPalette(DesignSystemMarkdownPalette(ctx.colors))
                .frame(maxWidth: .infinity, alignment: .leading)
        } else if BasicCatalog.containsMathDelimiters(text) {
            // Heading/caption variants keep their typography, so math inside
            // them is typeset inline at the variant's size instead of routing
            // through MarkdownView's body layout.
            MathText(text, mathFontSize: typography(for: c.variant).size)
                .typography(typography(for: c.variant))
                .fontWeight(c.weight.map { mapFontWeight(Int($0)) })
                .foregroundStyle(c.variant == .caption ? ctx.colors.onSurfaceVariant : ctx.colors.onSurface)
                .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            Text(text)
                .typography(typography(for: c.variant))
                .fontWeight(c.weight.map { mapFontWeight(Int($0)) })
                .foregroundStyle(c.variant == .caption ? ctx.colors.onSurfaceVariant : ctx.colors.onSurface)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    /// v1.0 has only two variants, `caption` and `body`; headings are expressed in Markdown instead.
    private func typography(for variant: TextVariant?) -> Typography {
        switch variant {
        case .caption: .labelSmall
        case .body, .none: .bodyMedium
        }
    }

    private func mapFontWeight(_ value: Int) -> Font.Weight {
        switch value {
        case ..<300: .light
        case 300..<400: .regular
        case 400..<500: .medium
        case 500..<600: .semibold
        case 600..<800: .bold
        default: .heavy
        }
    }

    /// Whether the text should go through the Markdown renderer.
    ///
    /// Since v1.0 dropped the heading variants, a heading arrives as Markdown (`## …`), so `body`
    /// and the unspecified variant are interpreted as Markdown. `caption` is supporting text and is
    /// always rendered literally, even when it happens to contain Markdown punctuation.
    private func shouldRenderMarkdown(_ text: String, variant: TextVariant?) -> Bool {
        guard !text.isEmpty else { return false }
        switch variant {
        case .caption: return false
        case .body, .none: return BasicCatalog.containsMarkdownFormatting(text)
        }
    }
}

/// Text-kind detection stays on `BasicCatalog` as statics: shared vocabulary that both the views
/// and the tests reach for.
extension BasicCatalog {
    static func containsMarkdownFormatting(_ s: String) -> Bool {
        if s.contains("**") || s.contains("__") || s.contains("`") { return true }
        if s.range(of: #"\[[^\]]+\]\([^)]+\)"#, options: .regularExpression) != nil { return true }
        if containsMathDelimiters(s) { return true }
        for rawLine in s.split(separator: "\n", omittingEmptySubsequences: false) {
            let line = rawLine.drop { $0 == " " }
            if line.hasPrefix("# ") || line.hasPrefix("## ") || line.hasPrefix("### ")
                || line.hasPrefix("#### ") || line.hasPrefix("##### ") { return true }
            if line.hasPrefix("- ") || line.hasPrefix("* ") || line.hasPrefix("+ ") { return true }
            if line.hasPrefix("> ") { return true }
            if line.range(of: #"^\d+\.\s"#, options: .regularExpression) != nil { return true }
        }
        return false
    }

    /// Detects math delimiters in LLM output.
    ///
    /// Deliberately loose: a false positive only costs a trip through the math render path, since
    /// the MarkdownView parser falls back to treating the text as plain prose anyway.
    static func containsMathDelimiters(_ s: String) -> Bool {
        if s.contains("$$") || s.contains(#"\("#) || s.contains(#"\["#) { return true }
        // Single `$`: only a same-line pair whose opener and closer are both hugging a non-space
        // character, which keeps currency amounts out.
        return s.range(of: #"\$\S(?:[^$\n]*\S)?\$"#, options: .regularExpression) != nil
    }
}

// Video and AudioPlayer render through MediaNodeView so they open in the in-app viewer.

// MARK: - Icon mapping (faithful port of A2UIRenderer.A2UIIcon)

extension BasicComponentView {
    /// Maps an icon name to an SF Symbol.
    ///
    /// A binding is matched against the preset names *after* it resolves through the data model,
    /// because the reference examples push preset names down that channel — `{"path": "/playIcon"}`
    /// resolving to `"pause"`. Only a name with no SF Symbol counterpart falls back to the
    /// question-mark glyph.
    private func symbol(for value: IconNameValue, in ctx: RenderContext<Catalog>) -> String {
        switch value {
        case .preset(let icon):
            return symbol(for: icon)
        case .binding(let binding):
            guard let icon = IconName(rawValue: ctx.resolve(.binding(binding))) else {
                return "questionmark.circle"
            }
            return symbol(for: icon)
        case .svgPath:
            // A custom SVG path has no SF Symbol equivalent; drawing it would need its own route.
            return "questionmark.circle"
        case .raw:
            return "questionmark.circle"
        }
    }

    private func symbol(for icon: IconName) -> String {
        return switch icon {
        case .accountCircle, .person: "person.circle"
        case .add: "plus"
        case .arrowBack: "chevron.left"
        case .arrowForward: "chevron.right"
        case .attachFile: "paperclip"
        case .calendarToday, .event: "calendar"
        case .call, .phone: "phone"
        case .camera: "camera"
        case .check: "checkmark"
        case .close: "xmark"
        case .delete: "trash"
        case .download: "arrow.down.circle"
        case .edit: "pencil"
        case .error: "exclamationmark.octagon"
        case .fastForward: "forward.fill"
        case .favorite: "heart.fill"
        case .favoriteOff: "heart"
        case .folder: "folder"
        case .help: "questionmark.circle"
        case .home: "house"
        case .info: "info.circle"
        case .locationOn: "location.fill"
        case .lock: "lock.fill"
        case .lockOpen: "lock.open.fill"
        case .mail: "envelope"
        case .menu: "line.3.horizontal"
        case .moreVert: "ellipsis"
        case .moreHoriz: "ellipsis"
        case .notificationsOff: "bell.slash"
        case .notifications: "bell"
        case .pause: "pause.fill"
        case .payment: "creditcard"
        case .photo: "photo"
        case .play: "play.fill"
        case .print: "printer"
        case .refresh: "arrow.clockwise"
        case .rewind: "backward.fill"
        case .search: "magnifyingglass"
        case .send: "paperplane.fill"
        case .settings: "gearshape"
        case .share: "square.and.arrow.up"
        case .shoppingCart: "cart"
        case .skipNext: "forward.end.fill"
        case .skipPrevious: "backward.end.fill"
        case .star: "star.fill"
        case .starHalf: "star.leadinghalf.filled"
        case .starOff: "star"
        case .stop: "stop.fill"
        case .upload: "arrow.up.circle"
        case .visibility: "eye"
        case .visibilityOff: "eye.slash"
        case .volumeDown: "speaker.wave.1"
        case .volumeMute: "speaker.slash"
        case .volumeOff: "speaker"
        case .volumeUp: "speaker.wave.3"
        case .warning: "exclamationmark.triangle"
        }
    }
}

// MARK: - Stateful components (need @State, so are View structs)

/// Gives a card its entrance and its scroll depth.
///
/// - On insertion: a fade plus a slight scale, so the card assembles rather than appears. It only
///   animates because `A2UISurfaceView` opens an animation context keyed on `structureVersion`,
///   which is what a streamed insertion bumps.
/// - On scroll: a card approaching the edge of the viewport dims, shrinks, and blurs. This needs a
///   host `ScrollView` to have any effect; outside one it is the identity.
struct CardMotionModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .transition(.opacity.combined(with: .scale(scale: 0.97, anchor: .top)))
            .scrollTransition(.interactive, axis: .vertical) { view, phase in
                view
                    .opacity(phase.isIdentity ? 1 : 0.55)
                    .scaleEffect(phase.isIdentity ? 1 : 0.97)
                    .blur(radius: phase.isIdentity ? 0 : 3)
            }
    }
}

/// `Row` — reads `weight` (flex-grow) and `justify` through `FlexRowLayout`, in the spec's sense.
///
/// The one exception to flex layout is a chip row: every child a `Button` and no `weight` anywhere,
/// which keeps its horizontal scroll. Child kinds are checked against the typed node
/// (`.known(.button)`) rather than by comparing component names as strings, and children come from
/// `ctx.children`, so a `{componentId, path}` template expands with a data scope per element.
///
/// Making the first child of a `spaceBetween` row greedy and pinning the rest to `fixedSize` was
/// tried and abandoned: against a weighted `Column` of long text it measures the intrinsic
/// single-line width and inflates the row past the edge of the screen.
struct RowNodeView<Catalog: RenderableCatalog>: View where Catalog.Node: BasicEmbeddingNode {
    @Environment(\.spacingScale) private var spacing
    let component: RowComponent
    let ctx: RenderContext<Catalog>

    private var kids: [ResolvedChild] { ctx.children(component.children) }

    private var isChipRow: Bool {
        component.justify == nil && !kids.isEmpty && kids.allSatisfy {
            if case .known(let node) = ctx.node($0.componentId), case .button? = node.basicComponent { return true }
            return false
        }
    }

    private var weights: [Double?] {
        kids.map { kid in
            if case .known(let node) = ctx.node(kid.componentId) { return node.layoutWeight }
            return nil
        }
    }

    var body: some View {
        let weights = weights
        // A declared weight states an intent to lay out with flex, so it beats the chip scroll.
        if !weights.contains(where: { $0 != nil }), component.justify == .start || isChipRow {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: component.align.vertical, spacing: spacing.sm) {
                    // fixedSize keeps each chip at its intrinsic width (no "…" truncation) — the
                    // mid-chip cut at the screen edge then reads as a scroll affordance, same as
                    // the tab bar's titles.
                    ForEach(kids, id: \.self) {
                        ctx.child($0).fixedSize(horizontal: true, vertical: false)
                    }
                }
            }
        } else {
            FlexRowLayout(justify: component.justify, align: component.align, spacing: spacing.sm) {
                ForEach(Array(kids.enumerated()), id: \.offset) { index, kid in
                    ctx.child(kid).layoutValue(key: FlexWeightKey.self, value: weights[index])
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

/// `Column` — a `VStack` whose alignment comes from `align`; template children expand through
/// `ctx.children`. Always claims the full proposed width, so a `Row` cannot size it by its content.
struct ColumnNodeView<Catalog: RenderableCatalog>: View where Catalog.Node: BasicEmbeddingNode {
    @Environment(\.spacingScale) private var spacing
    let component: ColumnComponent
    let ctx: RenderContext<Catalog>

    private var kids: [ResolvedChild] { ctx.children(component.children) }

    var body: some View {
        VStack(alignment: component.align.horizontal, spacing: spacing.md) {
            ForEach(kids, id: \.self) { ctx.child($0) }
        }
        .frame(maxWidth: .infinity, alignment: component.align.frameAlignment)
    }
}

/// `List` — vertical draws hairline separators between rows, horizontal becomes a scroll view with
/// no separators. Template children expand through `ctx.children`.
struct ListNodeView<Catalog: RenderableCatalog>: View where Catalog.Node: BasicEmbeddingNode {
    @Environment(\.colorPalette) private var colors
    @Environment(\.spacingScale) private var spacing
    let component: ListComponent
    let ctx: RenderContext<Catalog>

    private var kids: [ResolvedChild] { ctx.children(component.children) }

    var body: some View {
        if component.direction == .horizontal {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: component.align.vertical, spacing: spacing.sm) {
                    ForEach(kids, id: \.self) { ctx.child($0) }
                }
            }
        } else {
            VStack(alignment: component.align.horizontal, spacing: spacing.sm) {
                ForEach(Array(kids.enumerated()), id: \.offset) { index, kid in
                    if index > 0 {
                        Rectangle().fill(colors.outlineVariant.opacity(0.5)).frame(height: 1)
                    }
                    ctx.child(kid)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

/// `Image` — the `variant` fixes the size box and the clip shape; `avatar` is the one that clips to
/// a circle. The URL is resolved through the data context, so it may be a binding.
struct ImageNodeView<Catalog: RenderableCatalog>: View where Catalog.Node: BasicEmbeddingNode {
    let component: ImageComponent
    let ctx: RenderContext<Catalog>

    @Environment(\.radiusScale) private var radius
    @Environment(\.a2uiMediaViewerEnabled) private var viewerEnabled

    var body: some View {
        let url = URL(string: ctx.resolve(component.url))
        AsyncImage(url: url) { phase in
            switch phase {
            case .success(let image):
                sized(image)
            case .failure:
                Image(systemName: "photo").foregroundStyle(ctx.colors.onSurfaceVariant)
            default:
                ProgressView()
            }
        }
        .frame(maxWidth: maxWidth, maxHeight: maxHeight)
        .clipShape(RoundedRectangle(cornerRadius: component.variant == .avatar ? radius.full : radius.md))
        // Tap-to-fullscreen is standard client-side behavior, invisible to the schema. It is live
        // on iOS 18+ and the identity everywhere else.
        .mediaViewable(
            .image(url ?? URL(string: "https://example.invalid")!),
            enabled: viewerEnabled && url != nil
        )
        .accessibilityLabel(component.imageDescription.map { ctx.resolve($0) } ?? "")
    }

    /// Applies the `fit` mode without letting the image drive the layout.
    ///
    /// A bare `resizable()` + `.fill` ignores the proposed size and takes the image's native size as
    /// its layout size, spilling outside the frame — clipping only affects drawing, not layout. So
    /// `cover` pins the layout to a flexible `Color.clear` box at the variant's height and lets the
    /// image fill it as an overlay. A variant with no height cap has nothing to pin, so it falls
    /// back to `fit`.
    @ViewBuilder
    private func sized(_ image: SwiftUI.Image) -> some View {
        if component.fit == .cover, let coverHeight = maxHeight {
            Color.clear
                .frame(idealWidth: maxWidth == .infinity ? nil : maxWidth)
                .frame(height: coverHeight)
                .overlay(image.resizable().aspectRatio(contentMode: .fill))
                .clipped()
        } else {
            image.resizable().aspectRatio(contentMode: .fit)
        }
    }

    private var maxWidth: CGFloat? {
        switch component.variant {
        case .icon: 24
        case .avatar: 48
        case .smallFeature: 120
        case .mediumFeature: 220
        case .largeFeature, .header: .infinity
        default: .infinity
        }
    }
    private var maxHeight: CGFloat? {
        switch component.variant {
        case .icon: 24
        case .avatar: 48
        case .smallFeature: 120
        case .mediumFeature: 180
        case .header: 200
        default: nil
        }
    }
}

/// `Video` / `AudioPlayer` — a tappable tile that plays fullscreen in-app on iOS.
///
/// On iOS the tile opens the viewer through `mediaViewable`. On macOS there is no viewer, so it
/// stays a `Link` that hands the URL to the system, which is also the shape the parity goldens
/// expect.
struct MediaNodeView<Catalog: RenderableCatalog>: View where Catalog.Node: BasicEmbeddingNode {
    enum Kind {
        case video, audio

        var systemImage: String {
            switch self {
            case .video: "play.rectangle"
            case .audio: "speaker.wave.2"
            }
        }
    }

    let url: String
    let kind: Kind
    let ctx: RenderContext<Catalog>

    @Environment(\.radiusScale) private var radius
    @Environment(\.spacingScale) private var spacing
    @Environment(\.a2uiMediaViewerEnabled) private var viewerEnabled

    private var resolvedURL: URL? { URL(string: url) }

    var body: some View {
        #if os(iOS)
        Label(url.isEmpty ? RendererStrings.untitledMedia() : url, systemImage: kind.systemImage)
            .typography(.labelMedium)
            .lineLimit(1)
            .padding(spacing.sm)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(ctx.colors.surfaceVariant)
            .clipShape(RoundedRectangle(cornerRadius: radius.md))
            .mediaViewable(viewerItem, enabled: viewerEnabled && resolvedURL != nil)
        #else
        Link(destination: resolvedURL ?? URL(string: "https://example.invalid")!) {
            Label(url.isEmpty ? RendererStrings.untitledMedia() : url, systemImage: kind.systemImage).typography(.labelMedium)
        }
        #endif
    }

    #if os(iOS)
    private var viewerItem: MediaViewerItem {
        let target = resolvedURL ?? URL(string: "https://example.invalid")!
        switch kind {
        case .video: return .video(target)
        case .audio: return .audio(target)
        }
    }
    #endif
}

/// `Tabs` — a horizontally scrollable underline tab bar over a fixed baseline. The bar is hidden
/// for a single tab, and selection is local view state, so it resets if the node is rebuilt.
struct TabsNodeView<Catalog: RenderableCatalog>: View where Catalog.Node: BasicEmbeddingNode {
    @Environment(\.colorPalette) private var colors
    @Environment(\.spacingScale) private var spacing
    @Environment(\.motion) private var motion
    let component: TabsComponent
    let ctx: RenderContext<Catalog>
    @State private var selection = 0

    var body: some View {
        VStack(alignment: .leading, spacing: spacing.md) {
            if component.tabs.count > 1 { tabBar }
            if component.tabs.indices.contains(selection) {
                ctx.child(component.tabs[selection].child)
            }
        }
    }

    private var tabBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: spacing.lg) {
                ForEach(Array(component.tabs.enumerated()), id: \.offset) { index, tab in
                    let active = index == selection
                    Button {
                        withAnimation(motion.toggle) { selection = index }
                    } label: {
                        VStack(spacing: spacing.xs) {
                            Text(ctx.resolve(tab.title))
                                .typography(.labelLarge)
                                .foregroundStyle(active ? colors.primary : colors.onSurfaceVariant)
                                .lineLimit(1)
                                .fixedSize()
                            Rectangle()
                                .fill(active ? colors.primary : .clear)
                                .frame(height: 2)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .background(alignment: .bottom) {
            Rectangle().fill(colors.outlineVariant).frame(height: 1)
        }
    }
}

/// `Modal` — the `trigger` child is presented inline and a tap on it raises the `content` child in
/// a sheet with medium and large detents.
struct ModalNodeView<Catalog: RenderableCatalog>: View where Catalog.Node: BasicEmbeddingNode {
    @Environment(\.spacingScale) private var spacing
    let component: ModalComponent
    let ctx: RenderContext<Catalog>
    @State private var presented = false

    var body: some View {
        ctx.child(component.trigger)
            .onTapGesture { presented = true }
            .sheet(isPresented: $presented) {
                ScrollView {
                    ctx.child(component.content).padding(spacing.lg)
                }
                .presentationDetents([.medium, .large])
            }
    }
}

import SwiftUI
import DesignSystem
import SwiftMarkdownView
import A2UICore
import A2UICatalog
import A2UIRuntime
import A2UITyped

/// Basic catalog → SwiftUI as a single **exhaustive** `@ViewBuilder switch` over `BasicComponent`.
///
/// Zero string matching, zero `AnyView`, no `default` escape. Layout components (`Row`/`Column`/
/// `List`) are driven purely by `justify`/`align` — there is no child-type sniffing, so the
/// original "isChipRow hijacks spaceBetween" bug class cannot recur here.
///
/// Phase-2 scope: structure + display are real; interactive inputs render their current bound value
/// read-only (two-way write + `functionCall` side effects land in the reactive phase). Visual polish
/// (DesignSystem typography/colors) swaps in next; this pass uses plain SwiftUI for a reliable lock.
extension BasicCatalog: RenderableCatalog {
    public static func view(for node: BasicComponent, in ctx: RenderContext<BasicCatalog>) -> some View {
        BasicComponentView(component: node, ctx: ctx)
    }
}

/// Renders a `BasicComponent` inside ANY catalog whose node embeds the basic catalog —
/// the renderer-side counterpart of `CombinedNode` composition. A composed catalog's
/// `view(for:in:)` delegates its basic case here:
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
            // スタイル（solid / glass）はホストの `surfaceStyle` 環境で決まる（DS の Card が解決）。
            // 出現・スクロール時の奥行き演出は CardMotionModifier に集約。
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
            MarkdownView(text).frame(maxWidth: .infinity, alignment: .leading)
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

    private func typography(for variant: TextVariant?) -> Typography {
        switch variant {
        case .h1: .headlineSmall
        case .h2: .titleLarge
        case .h3: .titleMedium
        case .h4: .titleSmall
        case .h5: .labelLarge
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

    private func shouldRenderMarkdown(_ text: String, variant: TextVariant?) -> Bool {
        guard !text.isEmpty else { return false }
        switch variant {
        case .h1, .h2, .h3, .h4, .h5, .caption: return false
        case .body, .none: return BasicCatalog.containsMarkdownFormatting(text)
        }
    }
}

/// テキスト種別検出は BasicCatalog の static のまま（テスト・複数ビューから参照される共有語彙）。
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

    /// LLM 出力の数式デリミタ検出。誤検出は MarkdownView 側のパーサが
    /// 正しく平文扱いするため、ここは緩めで安全（コストは描画経路のみ）。
    static func containsMathDelimiters(_ s: String) -> Bool {
        if s.contains("$$") || s.contains(#"\("#) || s.contains(#"\["#) { return true }
        // single-$: 開き直後・閉じ直前が非空白の同一行ペアのみ（通貨除外）
        return s.range(of: #"\$\S(?:[^$\n]*\S)?\$"#, options: .regularExpression) != nil
    }
}

// （mediaLink は MediaNodeView へ置換 — Video/AudioPlayer のアプリ内ビューア化）

// MARK: - Icon mapping (faithful port of A2UIRenderer.A2UIIcon)

extension BasicComponentView {
    /// バインディングはデータモデル解決後に再度プリセット照合する（公式 example は
    /// `{"path": "/playIcon"}` → `"pause"` のようにプリセット名を流す）。SF Symbols に
    /// 写像できない名前だけがフォールバックに落ちる。
    private func symbol(for value: IconNameValue, in ctx: RenderContext<Catalog>) -> String {
        switch value {
        case .preset(let icon):
            return symbol(for: icon)
        case .binding(let binding):
            guard let icon = IconName(rawValue: ctx.resolve(.binding(binding))) else {
                return "questionmark.circle"
            }
            return symbol(for: icon)
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

/// `Row` — weight(flex-grow)と justify を FlexRowLayout で仕様の意味論どおりに解釈する。
/// 旧 "spaceBetween first child greedy"(2 番目以降を fixedSize)は、長文の weighted Column に
/// 当たると intrinsic 1 行幅で Row が画面外まで膨張するため廃止した。
/// カードの出現・スクロール演出。
///
/// - 挿入時: フェード + わずかなスケールで「組み上がる」出現（`A2UISurfaceView` が
///   `structureVersion` でアニメーション文脈を張るため、ストリーミング挿入で発火する）。
/// - スクロール時: 画面端に近づくカードを減光・縮小・ブラーして奥行きを表現する
///   （ホストの ScrollView 内でのみ作用。ScrollView 外では恒等）。
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

/// 全子が Button のチップ行(weight なし)だけは横スクロールを維持。Child-kind detection is
/// type-safe via the typed node (`.known(.button)`), not a string compare. Children resolve via
/// `ctx.children`, so `{componentId, path}` templates expand with per-element data scopes.
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
        // weight 宣言は flex レイアウトの意図表明なので、チップスクロールより優先する。
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

/// `Column` — faithful port of A2UIRenderer.ColumnView. Template children expand via `ctx.children`.
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

/// `List` — faithful port of A2UIRenderer.ListView (vertical: hairline separators; horizontal:
/// scroll). Template children expand via `ctx.children`.
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

/// `Image` — faithful port of A2UIRenderer.A2UIImage (variant sizing + clip shape).
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
        // クライアント側 UX としてタップ → フルスクリーンビューアを標準付与
        // （スキーマ非接触。iOS 18+ のみ動作、その他環境では恒等）
        .mediaViewable(
            .image(url ?? URL(string: "https://example.invalid")!),
            enabled: viewerEnabled && url != nil
        )
        .accessibilityLabel(component.imageDescription.map { ctx.resolve($0) } ?? "")
    }

    /// resizable + `.fill` を直接置くと、画像のレイアウトサイズが提案サイズを無視して
    /// 原寸まで膨らみフレーム外へあふれる（clip は描画にしか効かない）。
    /// cover はレイアウトを variant の高さで確定した flexible な箱（Color.clear）にし、
    /// 画像は overlay で描画だけ cover させる。高さ無制限の variant では cover が
    /// 成立しないため fit に落とす。
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

/// `Video` / `AudioPlayer` — タップでアプリ内フルスクリーン再生（iOS）。
///
/// iOS では DS スタイルのタップ可能タイルから `mediaViewable` でビューアを起動する。
/// macOS では従来どおり `Link` で外部に開く（機能退行ゼロ、Parity ゴールデンも同形を維持）。
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
        Label(url.isEmpty ? "メディア" : url, systemImage: kind.systemImage)
            .typography(.labelMedium)
            .lineLimit(1)
            .padding(spacing.sm)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(ctx.colors.surfaceVariant)
            .clipShape(RoundedRectangle(cornerRadius: radius.md))
            .mediaViewable(viewerItem, enabled: viewerEnabled && resolvedURL != nil)
        #else
        Link(destination: resolvedURL ?? URL(string: "https://example.invalid")!) {
            Label(url.isEmpty ? "メディア" : url, systemImage: kind.systemImage).typography(.labelMedium)
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

/// `Tabs` — faithful port of A2UIRenderer.TabsView (scrollable underline tab bar, fixed baseline).
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

/// `Modal` — faithful port of A2UIRenderer.ModalView (trigger → sheet with detents).
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

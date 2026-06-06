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
    @ViewBuilder
    public static func view(for node: BasicComponent, in ctx: RenderContext<BasicCatalog>) -> some View {
        switch node {
        case .text(let c):
            textView(c, in: ctx)

        case .image(let c):
            ImageNodeView(component: c, ctx: ctx)

        case .icon(let c):
            Image(systemName: symbol(for: c.name))
                .iconSize(.md)
                .foregroundStyle(ctx.colors.onSurfaceVariant)

        case .video(let c):
            mediaLink(url: ctx.resolve(c.url), system: "play.rectangle")

        case .audioPlayer(let c):
            mediaLink(url: ctx.resolve(c.url), system: "speaker.wave.2")

        case .row(let c):
            RowNodeView(component: c, ctx: ctx)

        case .column(let c):
            ColumnNodeView(component: c, ctx: ctx)

        case .list(let c):
            ListNodeView(component: c, ctx: ctx)

        case .card(let c):
            Card(elevation: .level1) { ctx.child(c.child) }

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

    @MainActor @ViewBuilder
    private static func textView(_ c: TextComponent, in ctx: RenderContext<BasicCatalog>) -> some View {
        let text = ctx.resolve(c.text)
        if shouldRenderMarkdown(text, variant: c.variant) {
            MarkdownView(text).frame(maxWidth: .infinity, alignment: .leading)
        } else {
            Text(text)
                .typography(typography(for: c.variant))
                .fontWeight(c.weight.map { mapFontWeight(Int($0)) })
                .foregroundStyle(c.variant == .caption ? ctx.colors.onSurfaceVariant : ctx.colors.onSurface)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private static func typography(for variant: TextVariant?) -> Typography {
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

    private static func mapFontWeight(_ value: Int) -> Font.Weight {
        switch value {
        case ..<300: .light
        case 300..<400: .regular
        case 400..<500: .medium
        case 500..<600: .semibold
        case 600..<800: .bold
        default: .heavy
        }
    }

    private static func shouldRenderMarkdown(_ text: String, variant: TextVariant?) -> Bool {
        guard !text.isEmpty else { return false }
        switch variant {
        case .h1, .h2, .h3, .h4, .h5, .caption: return false
        case .body, .none: return containsMarkdownFormatting(text)
        }
    }

    private static func containsMarkdownFormatting(_ s: String) -> Bool {
        if s.contains("**") || s.contains("__") || s.contains("`") { return true }
        if s.range(of: #"\[[^\]]+\]\([^)]+\)"#, options: .regularExpression) != nil { return true }
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

    @MainActor @ViewBuilder
    private static func mediaLink(url: String, system: String) -> some View {
        Link(destination: URL(string: url) ?? URL(string: "https://example.invalid")!) {
            Label(url.isEmpty ? "メディア" : url, systemImage: system).typography(.labelMedium)
        }
    }

    // MARK: - Icon mapping (faithful port of A2UIRenderer.A2UIIcon)

    private static func symbol(for value: IconNameValue) -> String {
        guard case .preset(let icon) = value else { return "questionmark.circle" }
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

/// `Row` — faithful port of A2UIRenderer.RowView (incl. the isChipRow horizontal-scroll heuristic,
/// spaceBetween "first child greedy" logic, and leading/trailing spacers). Child-kind detection is
/// type-safe via the typed node (`.known(.button)`), not a string compare. Children resolve via
/// `ctx.children`, so `{componentId, path}` templates expand with per-element data scopes.
struct RowNodeView: View {
    @Environment(\.spacingScale) private var spacing
    let component: RowComponent
    let ctx: RenderContext<BasicCatalog>

    private var kids: [ResolvedChild] { ctx.children(component.children) }

    private var isChipRow: Bool {
        component.justify == nil && !kids.isEmpty && kids.allSatisfy {
            if case .known(.button) = ctx.node($0.componentId) { return true }
            return false
        }
    }

    var body: some View {
        let justify = component.justify
        if justify == .start || isChipRow {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: component.align.vertical, spacing: spacing.sm) {
                    ForEach(kids, id: \.self) { ctx.child($0) }
                }
            }
        } else if justify == .spaceBetween {
            HStack(alignment: component.align.vertical, spacing: spacing.sm) {
                ForEach(Array(kids.enumerated()), id: \.offset) { index, kid in
                    if index == 0 {
                        ctx.child(kid)
                    } else {
                        ctx.child(kid).fixedSize(horizontal: true, vertical: false)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            HStack(alignment: component.align.vertical, spacing: spacing.sm) {
                if justify.leadingSpacer { Spacer(minLength: 0) }
                ForEach(kids, id: \.self) { ctx.child($0) }
                if justify.trailingSpacer { Spacer(minLength: 0) }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

/// `Column` — faithful port of A2UIRenderer.ColumnView. Template children expand via `ctx.children`.
struct ColumnNodeView: View {
    @Environment(\.spacingScale) private var spacing
    let component: ColumnComponent
    let ctx: RenderContext<BasicCatalog>

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
struct ListNodeView: View {
    @Environment(\.colorPalette) private var colors
    @Environment(\.spacingScale) private var spacing
    let component: ListComponent
    let ctx: RenderContext<BasicCatalog>

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
struct ImageNodeView: View {
    let component: ImageComponent
    let ctx: RenderContext<BasicCatalog>

    var body: some View {
        AsyncImage(url: URL(string: ctx.resolve(component.url))) { phase in
            switch phase {
            case .success(let image):
                image.resizable().aspectRatio(contentMode: component.fit == .cover ? .fill : .fit)
            case .failure:
                Image(systemName: "photo").foregroundStyle(.secondary)
            default:
                ProgressView()
            }
        }
        .frame(maxWidth: maxWidth, maxHeight: maxHeight)
        .clipShape(RoundedRectangle(cornerRadius: component.variant == .avatar ? 999 : 8))
        .accessibilityLabel(component.imageDescription.map { ctx.resolve($0) } ?? "")
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

/// `Tabs` — faithful port of A2UIRenderer.TabsView (scrollable underline tab bar, fixed baseline).
struct TabsNodeView: View {
    @Environment(\.colorPalette) private var colors
    @Environment(\.spacingScale) private var spacing
    let component: TabsComponent
    let ctx: RenderContext<BasicCatalog>
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
                        withAnimation(.easeInOut(duration: 0.18)) { selection = index }
                    } label: {
                        VStack(spacing: 6) {
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
struct ModalNodeView: View {
    let component: ModalComponent
    let ctx: RenderContext<BasicCatalog>
    @State private var presented = false

    var body: some View {
        ctx.child(component.trigger)
            .onTapGesture { presented = true }
            .sheet(isPresented: $presented) {
                ScrollView {
                    ctx.child(component.content).padding()
                }
                .presentationDetents([.medium, .large])
            }
    }
}

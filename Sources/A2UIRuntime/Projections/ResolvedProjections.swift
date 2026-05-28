import A2UICatalog
import A2UICore

// Type-safe, resolved projections of the Basic Catalog components.
//
// `ResolvedComponent` holds a dynamic `[String: AnyCodable]` of already-resolved props. These
// projections give each component a **strongly typed, compiler-checked** view of those props:
// scalar bindings are resolved to Swift values, enum fields use the catalog enum types, structural
// fields surface as `[ResolvedChild]`, and two-way fields expose write-back.
//
// A view does `let p = resolved.text` and then reads `p.text` / `p.variant` — a typo or a wrong
// type is a compile error, and there are no stringly-typed keys in view code.

/// A projection built from a `ResolvedComponent`. `@MainActor` because `ResolvedComponent` is.
@MainActor
public protocol ResolvedProjection {
    init(_ resolved: ResolvedComponent)
}

public extension ResolvedComponent {
    /// Project this component into a typed view (e.g. `resolved.projected(as: ResolvedText.self)`).
    func projected<P: ResolvedProjection>(as type: P.Type = P.self) -> P { P(self) }
}

// MARK: - Display

public struct ResolvedText: ResolvedProjection {
    public let text: String
    public let isTextPresent: Bool
    public let variant: TextVariant?
    public init(_ r: ResolvedComponent) {
        text = r.text("text")
        isTextPresent = r.isPresent("text")
        variant = r.decode(TextVariant.self, "variant")
    }
}

public struct ResolvedImage: ResolvedProjection {
    public let url: String
    public let isURLPresent: Bool
    public let description: String?
    public let fit: ImageFit?
    public let variant: ImageVariant?
    public init(_ r: ResolvedComponent) {
        url = r.text("url")
        isURLPresent = r.isPresent("url")
        description = r.string("description")
        fit = r.decode(ImageFit.self, "fit")
        variant = r.decode(ImageVariant.self, "variant")
    }
}

public struct ResolvedIcon: ResolvedProjection {
    public let name: String
    public init(_ r: ResolvedComponent) { name = r.text("name") }
}

public struct ResolvedVideo: ResolvedProjection {
    public let url: String
    public init(_ r: ResolvedComponent) { url = r.text("url") }
}

public struct ResolvedAudioPlayer: ResolvedProjection {
    public let url: String
    public let description: String?
    public init(_ r: ResolvedComponent) {
        url = r.text("url")
        description = r.string("description")
    }
}

// MARK: - Layout

public struct ResolvedRow: ResolvedProjection {
    public let children: [ResolvedChild]
    public let justify: LayoutJustify?
    public let align: LayoutAlign?
    public init(_ r: ResolvedComponent) {
        children = r.children
        justify = r.decode(LayoutJustify.self, "justify")
        align = r.decode(LayoutAlign.self, "align")
    }
}

public struct ResolvedColumn: ResolvedProjection {
    public let children: [ResolvedChild]
    public let justify: LayoutJustify?
    public let align: LayoutAlign?
    public init(_ r: ResolvedComponent) {
        children = r.children
        justify = r.decode(LayoutJustify.self, "justify")
        align = r.decode(LayoutAlign.self, "align")
    }
}

public struct ResolvedList: ResolvedProjection {
    public let children: [ResolvedChild]
    public let direction: ListDirection?
    public let align: LayoutAlign?
    public init(_ r: ResolvedComponent) {
        children = r.children
        direction = r.decode(ListDirection.self, "direction")
        align = r.decode(LayoutAlign.self, "align")
    }
}

public struct ResolvedCard: ResolvedProjection {
    public let child: ResolvedChild?
    public init(_ r: ResolvedComponent) { child = r.children.first }
}

public struct ResolvedTabs: ResolvedProjection {
    /// Tab titles paired with their child slots, in order.
    public let tabs: [(title: String, child: ResolvedChild)]
    public init(_ r: ResolvedComponent) {
        // Children are appended in tab order by ResolvedComponent; titles come from raw props.
        var titles: [String] = []
        if case .array(let arr)? = r.rawProps["tabs"] {
            for item in arr {
                if case .object(let dict) = item, case .string(let t)? = dict["title"] {
                    titles.append(t)
                } else {
                    titles.append("")
                }
            }
        }
        tabs = r.children.enumerated().map { (titles.indices.contains($0.offset) ? titles[$0.offset] : "", $0.element) }
    }
}

public struct ResolvedDivider: ResolvedProjection {
    public let axis: DividerAxis?
    public init(_ r: ResolvedComponent) { axis = r.decode(DividerAxis.self, "axis") }
}

public struct ResolvedModal: ResolvedProjection {
    public let trigger: ResolvedChild?
    public let content: ResolvedChild?
    public init(_ r: ResolvedComponent) {
        // ResolvedComponent appends trigger then content.
        trigger = r.children.first
        content = r.children.count > 1 ? r.children[1] : nil
    }
}

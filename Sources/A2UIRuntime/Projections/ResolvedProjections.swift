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

/// The two forms of an `Icon.name` schema field: a preset icon name (from a known set) or a raw
/// SVG path string. The catalog schema models this as `{ string | { svgPath: string } }`.
public enum ResolvedIconName: Sendable, Equatable {
    case preset(String)
    case svgPath(String)

    public init?(_ value: AnyCodable?) {
        switch value {
        case .string(let s):
            self = .preset(s)
        case .object(let dict):
            if case .string(let path)? = dict["svgPath"] {
                self = .svgPath(path)
            } else {
                return nil
            }
        default:
            return nil
        }
    }
}

public struct ResolvedIcon: ResolvedProjection {
    public let name: ResolvedIconName?
    public init(_ r: ResolvedComponent) {
        name = ResolvedIconName(r.props["name"])
    }
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
    /// Tab titles paired with their child slots, in order. Titles are `DynamicString`s — they may
    /// be plain literals or `{path}` bindings; this projection resolves both through the runtime's
    /// data context (correctly scoped) so views never see unresolved bindings.
    public let tabs: [(title: String, child: ResolvedChild)]
    public init(_ r: ResolvedComponent) {
        var titles: [String] = []
        if case .array(let arr)? = r.rawProps["tabs"] {
            for item in arr {
                if case .object(let dict) = item {
                    titles.append(r.resolveDynamicString(dict["title"]))
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

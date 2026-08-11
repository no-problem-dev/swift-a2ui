import StructuredDataCore
import Foundation
import A2UICore
import A2UICatalog
import JSONParsing

/// Builds the prompt's worked examples out of the Swift type system instead of hand-written JSON.
///
/// Hand-written example JSON goes quietly invalid: a wrong `version`, a `Modal` given
/// `children`, a stray `//` comment, a property that does not exist. Because the model copies
/// the example, every one of those defects becomes UI the client cannot render. Generating the
/// example from typed components and `AgentMessage` values and then serializing it puts the
/// compiler in charge of agreement with the catalog, and lets a test pin the exact output.
public enum A2UIExample {

    /// Encodes a typed catalog component such as `TextComponent` into the `StructuredValue`
    /// form that `UpdateComponents.components` expects.
    ///
    /// An encoding failure collapses to an empty object instead of throwing, so a component
    /// that cannot be encoded shows up as `{}` inside the example rather than stopping prompt
    /// assembly.
    public static func component(_ component: some Encodable & Sendable) -> StructuredValue {
        guard let data = try? JSONEncoder().encode(component),
              let value = try? JSONParser().parse(data) else {
            return .object([:])
        }
        return value
    }

    /// Wraps typed components into an `updateComponents` message for the given surface.
    ///
    /// The array order is preserved and carries meaning: the root must come first and every
    /// parent before its children, or a streaming client cannot render incrementally.
    public static func updateComponents(surfaceId: String, _ components: [any (Encodable & Sendable)]) -> AgentMessage {
        .updateComponents(UpdateComponents(surfaceId: surfaceId, components: components.map { component($0) }))
    }

    /// Serializes messages to a raw JSON array string with sorted keys and unescaped slashes.
    ///
    /// The output is byte-stable across runs, which is what keeps prompt caching effective,
    /// and the URLs in it stay readable. Wrapping conventions such as the `<a2ui-json>` tags
    /// are the caller's job; nothing is added here.
    public static func json(_ messages: [AgentMessage]) -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return (try? encoder.encode(messages)).map { String(decoding: $0, as: UTF8.self) } ?? "[]"
    }

    // MARK: - Reference example (the canonical prompt example, built from types)

    /// A data-model-driven reference surface that exercises the whole catalog palette.
    ///
    /// Built from typed components, so it is valid by construction. Pass it as the `examples:`
    /// argument of `A2UIPromptBuilder.buildSystemPrompt`. Do not pair it with a pruned catalog
    /// — it uses components an allowlist may have removed; use `presenterSurface` for that.
    ///
    /// The root is a full-width `Column` with `align: .stretch` rather than a `Card`: the host
    /// frame, not a card chrome, defines the surface bounds, which is the convention the
    /// official samples follow. How surfaces are arranged within a session — one at a time,
    /// paged, or stacked — lies outside the protocol and stays the app's decision.
    public static func referenceSurface(surfaceId id: String = "main") -> String {
        json(referenceMessages(surfaceId: id))
    }

    /// The reference surface as typed messages, before serialization.
    ///
    /// Public so a test can assert on the structure — component identifiers, ordering, binding
    /// paths — instead of on the JSON text, which sorting and escaping choices can churn.
    public static func referenceMessages(surfaceId id: String) -> [AgentMessage] {
        func path(_ p: String) -> DynamicString { .binding(DataBinding(path: p)) }
        func openUrl(_ p: String) -> Action {
            .functionCall(FunctionCall(call: "openUrl", args: ["url": .object(["path": .string(p)])]))
        }
        func followup(_ p: String) -> Action {
            .event(EventAction(name: "followup", context: ["ask": .binding(DataBinding(path: p))]))
        }

        // root is a full-width Column (align: .stretch) rather than a Card: the surface owns the whole
        // content region, so the host frame — not a card chrome — defines its bounds. Use Card only for
        // sub-regions inside a surface.
        let components: [any (Encodable & Sendable)] = [
            ColumnComponent(id: "root", children: .ids([
                "hero", "titleRow", "metaRow", "summary", "div1", "tabs", "div2",
                "formTitle", "nameField", "ticket", "datetime", "seats", "agree", "submit",
                "div3", "mapModal", "div4", "linksTitle", "links", "div5", "nextTitle", "followups",
            ]), align: .stretch),

            ImageComponent(id: "hero", url: path("/photo"), fit: .cover, variant: .largeFeature),
            RowComponent(id: "titleRow", children: .ids(["title", "badge"]), justify: .spaceBetween, align: .center),
            TextComponent(id: "title", text: path("/title")),
            TextComponent(id: "badge", text: path("/badge"), variant: .caption),
            RowComponent(id: "metaRow", children: .ids(["calIcon", "date", "locIcon", "venue"]), align: .center),
            IconComponent(id: "calIcon", name: .preset(.event)),
            TextComponent(id: "date", text: path("/date"), variant: .caption),
            IconComponent(id: "locIcon", name: .preset(.locationOn)),
            TextComponent(id: "venue", text: path("/venue"), variant: .caption),
            TextComponent(id: "summary", text: path("/summary"), variant: .body),

            DividerComponent(id: "div1"),
            TabsComponent(id: "tabs", tabs: [
                TabItem(title: "Overview", child: "about"),
                TabItem(title: "Schedule", child: "programList"),
            ]),
            TextComponent(id: "about", text: path("/about"), variant: .body),
            // Template-driven list: the canonical pattern for arrays. Teaches the spec's scope rule —
            // inside the instantiated template, paths WITHOUT a leading slash are RELATIVE to each
            // array element ("time" → /program/0/time); leading-slash paths stay absolute (root).
            ListComponent(id: "programList", children: .template(componentId: "programItem", path: "/program")),
            RowComponent(id: "programItem", children: .ids(["programTime", "programTitle"]), align: .center),
            TextComponent(id: "programTime", text: path("time"), variant: .caption),
            TextComponent(id: "programTitle", text: path("title"), variant: .body),

            DividerComponent(id: "div2"),
            TextComponent(id: "formTitle", text: "## Register"),
            TextFieldComponent(id: "nameField", label: "Your name", value: path("/form/name")),
            ChoicePickerComponent(
                id: "ticket",
                options: [ChoiceOption(label: "General", value: "general"), ChoiceOption(label: "Student", value: "student")],
                value: .binding(DataBinding(path: "/form/ticket")),
                variant: .mutuallyExclusive, displayStyle: .chips
            ),
            DateTimeInputComponent(id: "datetime", value: path("/form/date"), enableDate: true, label: "Preferred date"),
            SliderComponent(id: "seats", value: .binding(DataBinding(path: "/form/seats")), max: 8, label: "Seats", min: 1),
            CheckBoxComponent(id: "agree", label: "I agree to the terms", value: .binding(DataBinding(path: "/form/agree"))),
            ButtonComponent(
                id: "submit", child: "submitLabel",
                action: .event(EventAction(name: "register", context: ["name": .binding(DataBinding(path: "/form/name"))])),
                variant: .primary
            ),
            TextComponent(id: "submitLabel", text: "Register"),

            DividerComponent(id: "div3"),
            ModalComponent(id: "mapModal", trigger: "mapTrigger", content: "mapContent"),
            RowComponent(id: "mapTrigger", children: .ids(["mapIcon", "mapTriggerText"]), align: .center),
            IconComponent(id: "mapIcon", name: .preset(.locationOn)),
            TextComponent(id: "mapTriggerText", text: "See how to get there", variant: .body),
            ColumnComponent(id: "mapContent", children: .ids(["mapTitle", "mapBody"]), align: .stretch),
            TextComponent(id: "mapTitle", text: "## Getting there"),
            TextComponent(id: "mapBody", text: path("/access"), variant: .body),

            DividerComponent(id: "div4"),
            TextComponent(id: "linksTitle", text: "## Related links"),
            RowComponent(id: "links", children: .ids(["lk1", "lk2"]), justify: .start),
            ButtonComponent(id: "lk1", child: "lk1t", action: openUrl("/link1Url"), variant: .borderless),
            TextComponent(id: "lk1t", text: path("/link1Label")),
            ButtonComponent(id: "lk2", child: "lk2t", action: openUrl("/link2Url"), variant: .borderless),
            TextComponent(id: "lk2t", text: path("/link2Label")),

            DividerComponent(id: "div5"),
            TextComponent(id: "nextTitle", text: "### What people ask next"),
            RowComponent(id: "followups", children: .ids(["fu1", "fu2"]), justify: .start),
            ButtonComponent(id: "fu1", child: "fu1t", action: followup("/next1"), variant: .borderless),
            TextComponent(id: "fu1t", text: path("/next1")),
            ButtonComponent(id: "fu2", child: "fu2t", action: followup("/next2"), variant: .borderless),
            TextComponent(id: "fu2t", text: path("/next2")),
        ]

        let dataModel: StructuredValue = .object([
            "photo": .string("https://images.unsplash.com/photo-1505373877841-8d25f7d46678?w=600"),
            "title": .string("SwiftUI in Practice: A Hands-On Workshop"),
            "badge": .string("Almost full"),
            "date": .string("Sat, 12 Jul 2026, 13:00"),
            "venue": .string("Minatomirai, Yokohama"),
            "summary": .string("A small-group workshop on SwiftUI layout and animation you can use at work, taught by building."),
            "about": .string("Practical techniques for state, layout and animation. Aimed at intermediate developers."),
            "program": .array([
                .object(["time": .string("13:00"), "title": .string("Layout and state")]),
                .object(["time": .string("14:30"), "title": .string("Animation and navigation")]),
            ]),
            "access": .string("Five minutes from Minatomirai station; event space on basement level 2."),
            "link1Label": .string("Event details"), "link1Url": .string("https://example.com/event"),
            "link2Label": .string("Reports from past sessions"), "link2Url": .string("https://example.com/report"),
            "next1": .string("What should I bring or prepare?"),
            "next2": .string("Can I attend online?"),
            "form": .object(["name": .string(""), "ticket": .string("general"), "date": .string(""), "seats": .int(1), "agree": .bool(false)]),
        ])

        return [
            // Use the canonical catalogId (full URL), matching the official Python samples — not the
            // short name "basic". The renderer is catalog-agnostic, but the example is what the LLM
            // imitates, so it must teach the conformant identifier.
            .createSurface(CreateSurface(surfaceId: id, catalogId: BasicComponentCatalog.catalogId)),
            updateComponents(surfaceId: id, components),
            .updateDataModel(UpdateDataModel(surfaceId: id, path: "/", value: dataModel)),
        ]
    }

    // MARK: - Presenter example (content-presentation subset of the catalog)

    /// The component names `presenterMessages` is allowed to use.
    ///
    /// The catalog subset for content-presentation agents — no input controls, so nothing the
    /// model produces can ask the user to type. Pass it straight to
    /// `A2UIPromptBuilder(allowedComponents:)`. A test pins this set against the worked
    /// example, so the pruned schema and the example the model imitates cannot drift apart.
    public static let presenterComponentNames: Set<String> = [
        "Column", "Row", "Text", "Image", "Icon", "Divider", "List", "Card", "Button",
    ]

    /// The agent_to_renderer message names the presenter subset uses.
    ///
    /// Enough to create a surface, give it components, and fill its data model. The delete,
    /// call-function, and action-response messages are left out, so a presenter cannot tear
    /// down a surface or invoke client functions. Pass it straight to
    /// `A2UIPromptBuilder(allowedMessages:)`, or take `A2UIPromptBuilder.presenter()`, which
    /// applies it together with the matching component subset.
    public static let presenterMessageNames: Set<String> = [
        "CreateSurfaceMessage", "UpdateComponentsMessage", "UpdateDataModelMessage",
    ]

    /// A reference surface built only from the content-presentation subset.
    ///
    /// Where `referenceSurface` teaches the full catalog palette, this one shows that rich
    /// presentation is reachable with the nine components in `presenterComponentNames` alone.
    /// It is the counterpart to a catalog pruned to that same subset: pair them, or the model
    /// sees an example using components the schema no longer offers.
    public static func presenterSurface(surfaceId id: String = "main") -> String {
        json(presenterMessages(surfaceId: id))
    }

    /// The presenter surface as typed messages, before serialization.
    ///
    /// Public so a test can assert that it stays inside `presenterComponentNames` and
    /// `presenterMessageNames`, rather than parsing the JSON back out.
    public static func presenterMessages(surfaceId id: String) -> [AgentMessage] {
        func path(_ p: String) -> DynamicString { .binding(DataBinding(path: p)) }
        func openUrl(_ p: String) -> Action {
            .functionCall(FunctionCall(call: "openUrl", args: ["url": .object(["path": .string(p)])]))
        }
        func followup(_ p: String) -> Action {
            .event(EventAction(name: "followup", context: ["ask": .binding(DataBinding(path: p))]))
        }

        let components: [any (Encodable & Sendable)] = [
            ColumnComponent(id: "root", children: .ids([
                "hero", "titleRow", "metaRow", "summary", "div1",
                "highlightsTitle", "highlights", "div2", "detailCard",
                "div3", "sourcesTitle", "sources", "div4", "nextTitle", "followups",
            ]), align: .stretch),

            ImageComponent(id: "hero", url: path("/photo"), fit: .cover, variant: .largeFeature),
            RowComponent(id: "titleRow", children: .ids(["title", "badge"]), justify: .spaceBetween, align: .center),
            TextComponent(id: "title", text: path("/title")),
            TextComponent(id: "badge", text: path("/badge"), variant: .caption),
            RowComponent(id: "metaRow", children: .ids(["metaIcon", "metaText"]), align: .center),
            IconComponent(id: "metaIcon", name: .preset(.event)),
            TextComponent(id: "metaText", text: path("/meta"), variant: .caption),
            TextComponent(id: "summary", text: path("/summary"), variant: .body),

            DividerComponent(id: "div1"),
            TextComponent(id: "highlightsTitle", text: "## Highlights"),
            // Template-driven list: the canonical pattern for arrays. Teaches the spec's scope rule —
            // inside the instantiated template, paths WITHOUT a leading slash are RELATIVE to each
            // array element ("label" → /highlights/0/label); leading-slash paths stay absolute (root).
            ListComponent(id: "highlights", children: .template(componentId: "highlightItem", path: "/highlights")),
            RowComponent(id: "highlightItem", children: .ids(["highlightIcon", "highlightText"]), align: .center),
            IconComponent(id: "highlightIcon", name: .preset(.check)),
            TextComponent(id: "highlightText", text: path("label"), variant: .body),

            DividerComponent(id: "div2"),
            // Card is for sub-sections inside the surface — never the root.
            CardComponent(id: "detailCard", child: "detailBody"),
            ColumnComponent(id: "detailBody", children: .ids(["detailTitle", "detailText"]), align: .stretch),
            TextComponent(id: "detailTitle", text: path("/detailTitle")),
            TextComponent(id: "detailText", text: path("/detailText"), variant: .body),

            DividerComponent(id: "div3"),
            TextComponent(id: "sourcesTitle", text: "## Sources"),
            RowComponent(id: "sources", children: .ids(["src1", "src2"]), justify: .start),
            ButtonComponent(id: "src1", child: "src1t", action: openUrl("/source1Url"), variant: .borderless),
            TextComponent(id: "src1t", text: path("/source1Label")),
            ButtonComponent(id: "src2", child: "src2t", action: openUrl("/source2Url"), variant: .borderless),
            TextComponent(id: "src2t", text: path("/source2Label")),

            DividerComponent(id: "div4"),
            TextComponent(id: "nextTitle", text: "### What people ask next"),
            RowComponent(id: "followups", children: .ids(["fu1", "fu2"]), justify: .start),
            ButtonComponent(id: "fu1", child: "fu1t", action: followup("/next1"), variant: .borderless),
            TextComponent(id: "fu1t", text: path("/next1")),
            ButtonComponent(id: "fu2", child: "fu2t", action: followup("/next2"), variant: .borderless),
            TextComponent(id: "fu2t", text: path("/next2")),
        ]

        let dataModel: StructuredValue = .object([
            "photo": .string("https://images.unsplash.com/photo-1505373877841-8d25f7d46678?w=600"),
            "title": .string("Where Swift Concurrency migration stands"),
            "badge": .string("As of June 2026"),
            "meta": .string("4 sources · last updated 2026/06"),
            "summary": .string("Migrating to Swift 6 strict concurrency is settling into a staged approach."),
            "highlights": .array([
                .object(["label": .string("@MainActor by default cuts the cost of migrating the UI layer sharply")]),
                .object(["label": .string("Sendable conformance is now effectively required of libraries")]),
                .object(["label": .string("Enabling it target by target is the recommended path")]),
            ]),
            "detailTitle": .string("How to approach the migration"),
            "detailText": .string("Start in warnings-only minimal mode to size the impact, then work Sendable outward from the module boundaries."),
            "source1Label": .string("Swift.org migration guide"), "source1Url": .string("https://swift.org/migration"),
            "source2Label": .string("WWDC session"), "source2Url": .string("https://developer.apple.com/videos"),
            "next1": .string("What warnings does existing code usually hit?"),
            "next2": .string("What do library authors need to do?"),
        ])

        return [
            .createSurface(CreateSurface(surfaceId: id, catalogId: BasicComponentCatalog.catalogId)),
            updateComponents(surfaceId: id, components),
            .updateDataModel(UpdateDataModel(surfaceId: id, path: "/", value: dataModel)),
        ]
    }
}

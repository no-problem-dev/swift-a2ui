import Foundation
import A2UICore
import A2UICatalog
import JSONParsing

/// Builds prompt **examples from the Swift type system** instead of hand-written JSON strings.
///
/// Hand-authored example strings drift and silently go invalid (wrong `version`, a Modal with
/// `children` instead of `trigger`/`content`, stray `//` comments, non-existent props). By
/// constructing the example from the typed components + `ServerMessage`s and serializing, the example
/// is **guaranteed structurally valid** against the catalog types, and a test can pin it.
public enum A2UIExample {

    /// Encode a typed catalog component (e.g. `TextComponent`) into the `StructuredValue` form that
    /// `UpdateComponents.components` expects.
    public static func component(_ component: some Encodable & Sendable) -> StructuredValue {
        guard let data = try? JSONEncoder().encode(component),
              let value = try? JSONParser().parse(data) else {
            return .object([:])
        }
        return value
    }

    /// Convenience: an `updateComponents` message from typed components.
    public static func updateComponents(surfaceId: String, _ components: [any (Encodable & Sendable)]) -> ServerMessage {
        .updateComponents(UpdateComponents(surfaceId: surfaceId, components: components.map { component($0) }))
    }

    /// Render a list of messages as a raw JSON array. Keys are sorted and slashes are not escaped,
    /// so the embedded JSON is deterministic (stable prompt cache) and URL-clean.
    /// Wrapping conventions (e.g. `<a2ui-json>` tags for the text-tags method) belong to the consumer.
    public static func json(_ messages: [ServerMessage]) -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return (try? encoder.encode(messages)).map { String(decoding: $0, as: UTF8.self) } ?? "[]"
    }

    // MARK: - Reference example (the canonical prompt example, built from types)

    /// A data-model-driven reference surface covering the catalog palette, built entirely from typed
    /// components so it is guaranteed valid (no stray comments, no `children`-Modal, correct version).
    /// Use as the `examples:` argument to `A2UIPromptBuilder.buildSystemPrompt`.
    ///
    /// The root is a full-width `Column` (align: stretch): the host frame defines the surface bounds,
    /// matching the official v0.9 sample convention. How surfaces are *arranged over a session*
    /// (single / paged / stacked) is a separate, out-of-protocol concern owned by the consuming app.
    public static func referenceSurface(surfaceId id: String = "main") -> String {
        json(referenceMessages(surfaceId: id))
    }

    /// The reference surface as typed messages (exposed so tests can assert structure).
    public static func referenceMessages(surfaceId id: String) -> [ServerMessage] {
        func path(_ p: String) -> DynamicString { .binding(DataBinding(path: p)) }
        func openUrl(_ p: String) -> Action {
            .functionCall(FunctionCall(call: "openUrl", args: ["url": .object(["path": .string(p)])], returnType: .void))
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
            TextComponent(id: "title", text: path("/title"), variant: .h2),
            TextComponent(id: "badge", text: path("/badge"), variant: .caption),
            RowComponent(id: "metaRow", children: .ids(["calIcon", "date", "locIcon", "venue"]), align: .center),
            IconComponent(id: "calIcon", name: .preset(.event)),
            TextComponent(id: "date", text: path("/date"), variant: .caption),
            IconComponent(id: "locIcon", name: .preset(.locationOn)),
            TextComponent(id: "venue", text: path("/venue"), variant: .caption),
            TextComponent(id: "summary", text: path("/summary"), variant: .body),

            DividerComponent(id: "div1"),
            TabsComponent(id: "tabs", tabs: [
                TabItem(title: "概要", child: "about"),
                TabItem(title: "プログラム", child: "programList"),
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
            TextComponent(id: "formTitle", text: "参加登録", variant: .h3),
            TextFieldComponent(id: "nameField", label: "お名前", value: path("/form/name")),
            ChoicePickerComponent(
                id: "ticket",
                options: [ChoiceOption(label: "一般", value: "一般"), ChoiceOption(label: "学生", value: "学生")],
                value: .binding(DataBinding(path: "/form/ticket")),
                variant: .mutuallyExclusive, displayStyle: .chips
            ),
            DateTimeInputComponent(id: "datetime", value: path("/form/date"), enableDate: true, label: "参加希望日"),
            SliderComponent(id: "seats", value: .binding(DataBinding(path: "/form/seats")), max: 8, label: "参加人数", min: 1),
            CheckBoxComponent(id: "agree", label: "参加規約に同意する", value: .binding(DataBinding(path: "/form/agree"))),
            ButtonComponent(
                id: "submit", child: "submitLabel",
                action: .event(EventAction(name: "register", context: ["name": .binding(DataBinding(path: "/form/name"))])),
                variant: .primary
            ),
            TextComponent(id: "submitLabel", text: "申し込む"),

            DividerComponent(id: "div3"),
            ModalComponent(id: "mapModal", trigger: "mapTrigger", content: "mapContent"),
            RowComponent(id: "mapTrigger", children: .ids(["mapIcon", "mapTriggerText"]), align: .center),
            IconComponent(id: "mapIcon", name: .preset(.locationOn)),
            TextComponent(id: "mapTriggerText", text: "アクセスマップを見る", variant: .body),
            ColumnComponent(id: "mapContent", children: .ids(["mapTitle", "mapBody"]), align: .stretch),
            TextComponent(id: "mapTitle", text: "アクセス", variant: .h3),
            TextComponent(id: "mapBody", text: path("/access"), variant: .body),

            DividerComponent(id: "div4"),
            TextComponent(id: "linksTitle", text: "関連リンク", variant: .h3),
            RowComponent(id: "links", children: .ids(["lk1", "lk2"]), justify: .start),
            ButtonComponent(id: "lk1", child: "lk1t", action: openUrl("/link1Url"), variant: .borderless),
            TextComponent(id: "lk1t", text: path("/link1Label")),
            ButtonComponent(id: "lk2", child: "lk2t", action: openUrl("/link2Url"), variant: .borderless),
            TextComponent(id: "lk2t", text: path("/link2Label")),

            DividerComponent(id: "div5"),
            TextComponent(id: "nextTitle", text: "次に気になること", variant: .h4),
            RowComponent(id: "followups", children: .ids(["fu1", "fu2"]), justify: .start),
            ButtonComponent(id: "fu1", child: "fu1t", action: followup("/next1"), variant: .borderless),
            TextComponent(id: "fu1t", text: path("/next1")),
            ButtonComponent(id: "fu2", child: "fu2t", action: followup("/next2"), variant: .borderless),
            TextComponent(id: "fu2t", text: path("/next2")),
        ]

        let dataModel: StructuredValue = .object([
            "photo": .string("https://images.unsplash.com/photo-1505373877841-8d25f7d46678?w=600"),
            "title": .string("SwiftUI 実践ワークショップ"),
            "badge": .string("残りわずか"),
            "date": .string("2026/07/12 (土) 13:00"),
            "venue": .string("横浜・みなとみらい"),
            "summary": .string("現場で使える SwiftUI の設計とアニメーションを、手を動かしながら学ぶ少人数ワークショップです。"),
            "about": .string("状態管理・レイアウト・アニメーションの実践テクニックを習得します。中級者向け。"),
            "program": .array([
                .object(["time": .string("13:00"), "title": .string("レイアウトと状態管理")]),
                .object(["time": .string("14:30"), "title": .string("アニメーションと画面遷移")]),
            ]),
            "access": .string("みなとみらい駅から徒歩5分、地下2階イベントスペース。"),
            "link1Label": .string("イベント詳細"), "link1Url": .string("https://example.com/event"),
            "link2Label": .string("過去の開催レポート"), "link2Url": .string("https://example.com/report"),
            "next1": .string("持ち物・事前準備は？"),
            "next2": .string("オンライン参加はできる？"),
            "form": .object(["name": .string(""), "ticket": .string("一般"), "date": .string(""), "seats": .int(1), "agree": .bool(false)]),
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
}

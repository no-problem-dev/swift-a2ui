import Foundation
import A2UICore
import A2UICatalog
import JSONParsing

/// 手書き JSON 文字列の代わりに Swift の型システムからプロンプト手本を生成するユーティリティ。
///
/// 手書きの JSON 文字列は `version` の誤り・`children` を持つ `Modal`・余分な `//` コメント・
/// 存在しないプロパティなど暗黙の不正が紛れ込む。型付きコンポーネントと `ServerMessage` から
/// 生成してシリアライズすることで、カタログ型との整合性がコンパイル時に保証され、テストでピン留めできる。
public enum A2UIExample {

    /// 型付きカタログコンポーネント（例: `TextComponent`）を `UpdateComponents.components` が
    /// 期待する `StructuredValue` 形式にエンコードする。
    public static func component(_ component: some Encodable & Sendable) -> StructuredValue {
        guard let data = try? JSONEncoder().encode(component),
              let value = try? JSONParser().parse(data) else {
            return .object([:])
        }
        return value
    }

    /// 型付きコンポーネント配列から `updateComponents` メッセージを生成するヘルパー。
    public static func updateComponents(surfaceId: String, _ components: [any (Encodable & Sendable)]) -> ServerMessage {
        .updateComponents(UpdateComponents(surfaceId: surfaceId, components: components.map { component($0) }))
    }

    /// メッセージ配列を生の JSON 配列文字列に変換する。キーはソート済みでスラッシュは非エスケープ —
    /// プロンプトキャッシュが安定し URL クリーンな決定論的出力になる。
    /// `<a2ui-json>` タグ等のラッピング規約は呼び出し側が担う。
    public static func json(_ messages: [ServerMessage]) -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return (try? encoder.encode(messages)).map { String(decoding: $0, as: UTF8.self) } ?? "[]"
    }

    // MARK: - Reference example (the canonical prompt example, built from types)

    /// カタログパレット全体をカバーするデータモデル駆動の参照サーフェス。型付きコンポーネントから
    /// 生成するため常に有効（余分なコメント・`children` を持つ `Modal`・バージョン誤り等が混入しない）。
    /// `A2UIPromptBuilder.buildSystemPrompt` の `examples:` 引数として渡す。
    ///
    /// ルートは全幅 `Column`（align: stretch）: ホストフレームがサーフェス境界を定め、
    /// 公式 v0.9 サンプルの規約に準拠する。セッション内でのサーフェス配置（単一 / ページング /
    /// スタック）はプロトコル外の関心事であり、アプリ側が担う。
    public static func referenceSurface(surfaceId id: String = "main") -> String {
        json(referenceMessages(surfaceId: id))
    }

    /// 型付きメッセージ配列としての参照サーフェス（テストで構造を検証するために公開）。
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

    // MARK: - Presenter example (content-presentation subset of the catalog)

    /// `presenterMessages` が使ってよいコンポーネント名。コンテンツ提示（presenter）型の
    /// エージェント向けカタログ・サブセットで、`A2UIPromptBuilder(allowedComponents:)` に
    /// そのまま渡せる。手本と許可セットの同期はテストで固定される。
    public static let presenterComponentNames: Set<String> = [
        "Column", "Row", "Text", "Image", "Icon", "Divider", "List", "Card", "Button",
    ]

    /// presenter サブセットが使う server_to_client メッセージ名。
    /// `A2UIPromptBuilder(allowedMessages:)` にそのまま渡せる。
    public static let presenterMessageNames: Set<String> = [
        "CreateSurfaceMessage", "UpdateComponentsMessage", "UpdateDataModelMessage",
    ]

    /// コンテンツ提示に特化した参照サーフェス。`referenceSurface` がカタログ全パレットを
    /// 教えるのに対し、こちらは `presenterComponentNames` の 9 種だけで「リッチな提示」を
    /// 教える — pruning したカタログと手本が矛盾しないための対。
    public static func presenterSurface(surfaceId id: String = "main") -> String {
        json(presenterMessages(surfaceId: id))
    }

    /// 型付きメッセージ配列としての presenter サーフェス（テストで構造を検証するために公開）。
    public static func presenterMessages(surfaceId id: String) -> [ServerMessage] {
        func path(_ p: String) -> DynamicString { .binding(DataBinding(path: p)) }
        func openUrl(_ p: String) -> Action {
            .functionCall(FunctionCall(call: "openUrl", args: ["url": .object(["path": .string(p)])], returnType: .void))
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
            TextComponent(id: "title", text: path("/title"), variant: .h2),
            TextComponent(id: "badge", text: path("/badge"), variant: .caption),
            RowComponent(id: "metaRow", children: .ids(["metaIcon", "metaText"]), align: .center),
            IconComponent(id: "metaIcon", name: .preset(.event)),
            TextComponent(id: "metaText", text: path("/meta"), variant: .caption),
            TextComponent(id: "summary", text: path("/summary"), variant: .body),

            DividerComponent(id: "div1"),
            TextComponent(id: "highlightsTitle", text: "ポイント", variant: .h3),
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
            TextComponent(id: "detailTitle", text: path("/detailTitle"), variant: .h4),
            TextComponent(id: "detailText", text: path("/detailText"), variant: .body),

            DividerComponent(id: "div3"),
            TextComponent(id: "sourcesTitle", text: "出典", variant: .h3),
            RowComponent(id: "sources", children: .ids(["src1", "src2"]), justify: .start),
            ButtonComponent(id: "src1", child: "src1t", action: openUrl("/source1Url"), variant: .borderless),
            TextComponent(id: "src1t", text: path("/source1Label")),
            ButtonComponent(id: "src2", child: "src2t", action: openUrl("/source2Url"), variant: .borderless),
            TextComponent(id: "src2t", text: path("/source2Label")),

            DividerComponent(id: "div4"),
            TextComponent(id: "nextTitle", text: "次に気になること", variant: .h4),
            RowComponent(id: "followups", children: .ids(["fu1", "fu2"]), justify: .start),
            ButtonComponent(id: "fu1", child: "fu1t", action: followup("/next1"), variant: .borderless),
            TextComponent(id: "fu1t", text: path("/next1")),
            ButtonComponent(id: "fu2", child: "fu2t", action: followup("/next2"), variant: .borderless),
            TextComponent(id: "fu2t", text: path("/next2")),
        ]

        let dataModel: StructuredValue = .object([
            "photo": .string("https://images.unsplash.com/photo-1505373877841-8d25f7d46678?w=600"),
            "title": .string("Swift Concurrency 移行の現在地"),
            "badge": .string("2026年6月時点"),
            "meta": .string("調査ソース 4 件・最終更新 2026/06"),
            "summary": .string("Swift 6 の strict concurrency への移行は、段階的アプローチが主流になりつつあります。"),
            "highlights": .array([
                .object(["label": .string("@MainActor 既定化で UI 層の移行コストが大幅減")]),
                .object(["label": .string("ライブラリは Sendable 対応が事実上の必須要件に")]),
                .object(["label": .string("移行は target 単位の段階的有効化が推奨")]),
            ]),
            "detailTitle": .string("移行の進め方"),
            "detailText": .string("まず警告のみの minimal モードで影響範囲を把握し、モジュール境界から Sendable を整えるのが定石です。"),
            "source1Label": .string("Swift.org 移行ガイド"), "source1Url": .string("https://swift.org/migration"),
            "source2Label": .string("WWDC セッション"), "source2Url": .string("https://developer.apple.com/videos"),
            "next1": .string("既存コードの典型的な警告は？"),
            "next2": .string("ライブラリ側の対応手順は？"),
        ])

        return [
            .createSurface(CreateSurface(surfaceId: id, catalogId: BasicComponentCatalog.catalogId)),
            updateComponents(surfaceId: id, components),
            .updateDataModel(UpdateDataModel(surfaceId: id, path: "/", value: dataModel)),
        ]
    }
}

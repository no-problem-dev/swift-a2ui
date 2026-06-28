import SwiftUI
import DesignSystem
import A2UICore
import A2UIRuntime
import A2UITyped

/// 自身の `Node` を SwiftUI へ描画する方法を知るカタログ。
///
/// UI 非依存の `A2UICatalog` とは分離しているため、型付きカタログコアに SwiftUI 依存が生じない。
/// 準拠型はノードのサム型を網羅する `@ViewBuilder switch` を実装する —
/// 文字列照合なし・`AnyView` なし・型安全。
@MainActor
public protocol RenderableCatalog: A2UICatalog {
    associatedtype NodeBody: View
    static func view(for node: Node, in ctx: RenderContext<Self>) -> NodeBody
}

/// カタログの `view(for:in:)` へ渡すレンダリング時コンテキスト: データスコープ + 子レンダリング。
///
/// カタログに対してジェネリック — これが「ウイルス性ジェネリクス」の具体的なコスト。
/// 型消去ゼロの代償として `child(_:)` は `AnyView` でなく具体的な `NodeView<Catalog>` を返す。
@MainActor
public struct RenderContext<Catalog: RenderableCatalog> {
    let surface: TypedSurface<Catalog>
    let scope: String
    /// デザインシステムカラーパレット（テーマ / ダークモード）。リーフビューが参照する。
    let colors: any ColorPalette
    /// 環境の URL オープナー — `functionCall: openUrl` の唯一の副作用シンク（旧 ClientFunctions
    /// パスに一致）。テスト / ビュー構築以外では no-op がデフォルト。
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

    /// 現在のスコープのデータコンテキスト。Basic Catalog の関数レジストリを組み込み済みで、
    /// `{call: …}` 動的値と `checks`（関数呼び出し）が実際に解決される。
    var dataContext: DataContext {
        DataContext(dataModel: surface.dataModel, path: scope, functions: BasicFunctions())
    }

    // MARK: - Client-side validation (`checks` / Checkable)

    /// 全 check が通過した場合（または check が存在しない場合）に true を返す。
    /// 仕様: check が失敗した Button は無効化される。データバージョンを追跡し、
    /// データ編集のたびに checks をリアクティブに再評価する。
    public func checksPass(_ checks: [CheckRule]?) -> Bool {
        guard let checks, !checks.isEmpty else { return true }
        trackData()
        return ChecksEvaluator.allPass(checks, in: dataContext)
    }

    /// 最初に失敗した check のメッセージ（アクティブな検証エラー）、なければ nil。リアクティブ。
    public func firstCheckFailure(_ checks: [CheckRule]?) -> String? {
        guard let checks, !checks.isEmpty else { return nil }
        trackData()
        return ChecksEvaluator.firstFailure(checks, in: dataContext)
    }

    /// バインド可能な文字列（`literal` / `{path}` / `{call}`）を現在のスコープで解決する。
    /// 非リテラル値は `dataVersion` を追跡するため、データモデル更新で読み取りビューが再描画される。
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

    /// サーフェスのデータバージョンへの SwiftUI 依存を確立する（バインディングのリアクティビティ）。
    private func trackData() { _ = surface.dataVersion }

    /// コンポーネントの `action` をディスパッチする:
    /// - `.event` → コンテキスト引数をスコープで解決し、ホスト（`onEvent`）へ渡す。
    /// - `.functionCall openUrl` → `url` 引数を解決し、環境の URL オープナーで開く。
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

    /// リテラルまたは `{path}` バインディングを含む関数呼び出し引数を解決する。
    private func resolveArg(_ value: StructuredValue?) -> StructuredValue? {
        guard let value else { return nil }
        if case .object(let dict) = value, case .string(let path)? = dict["path"], dict.count == 1 {
            return surface.dataModel.get(path, scope: scope)
        }
        return value
    }

    /// id で子をレンダリングする — `NodeView` による名前付き型で型安全を保つ再帰的セアム。
    public func child(_ id: ComponentId) -> NodeView<Catalog> {
        NodeView(surface: surface, id: id, scope: scope)
    }

    /// `ChildList` を具体的な子スロットへ解決し、`{componentId, path}` テンプレートを
    /// バインドされたコレクションで展開する（仕様 §collection scopes）。展開はデータモデルを読むため
    /// `dataVersion` を追跡 — コレクション変更でコンテナが再描画される。公式 lit レンダラーの
    /// `A2uiChildRef` 形状（`{id, basePath}`、scope = basePath ?? parentPath）に準拠。
    public func children(_ list: ChildList) -> [ResolvedChild] {
        if case .template = list { trackData() }
        return TemplateExpander.expand(list, in: dataContext)
    }

    /// 解決済みの子スロットをレンダリングする — テンプレートインスタンスは要素スコープ（`basePath`）を持つ。
    public func child(_ resolved: ResolvedChild) -> NodeView<Catalog> {
        NodeView(surface: surface, id: resolved.componentId, scope: resolved.basePath)
    }

    /// 子ノードを検索する（例: レイアウト判断のために種別を型安全に確認する場合）。
    public func node(_ id: ComponentId) -> CatalogNode<Catalog.Node>? { surface.node(id) }

    // MARK: - Two-way binding (inputs write back to the data model at the bound path)

    /// `path`（スコープで解決）に値を書き込み、依存ビューを再解決する。
    public func write(_ path: String, _ value: StructuredValue?) {
        dataContext.set(path, value)
        surface.touchData()
    }

    /// `DynamicString` に対する `Binding<String>`: 読み取りは解決し、書き込みはバインドパスへ反映する
    ///（リテラルは書き込み先がないため no-op — 旧 `Writable` セマンティクスのミラー）。
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

    /// `DynamicStringList`（ChoicePicker の選択値）を現在の `[String]` に解決する。
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

/// 再帰ディスパッチャ: 一つの id をノードへ解決して描画する。`.known` はカタログの網羅的な
/// ビューマッピングへ委譲し、`.unknown` は仕様が定めるグレースフルフォールバックを表示する。
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

/// サーフェス全体をルートからレンダリングするエントリーポイント。A2UIRenderer.SurfaceView の忠実な移植で、
/// `busy` 処理（無効化 + 減光 + "実行中" ピル）と生成中プレースホルダーを含む。
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
            // ストリーミングで部品が流れ込むたびに、挿入トランジション（カードの
            // フェード+スケール等）をアニメーション付きで再生する（カスケード組み上がり）
            .animation(motion.stream, value: surface.structureVersion)
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
        // elevation はダークモードで不透明度を自動調整する（直接 shadow は固定値になる）
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
